#include "social/SocialClient.h"

#include <QClipboard>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonValue>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSettings>
#include <QUrl>

SocialClient::SocialClient(QObject *parent)
    : QObject(parent)
{
    QSettings settings;
    m_serviceUrl = settings.value(QStringLiteral("social/serviceUrl")).toString();

    m_refreshTimer.setInterval(15000);
    m_refreshTimer.setSingleShot(false);
    connect(&m_refreshTimer, &QTimer::timeout, this, &SocialClient::refresh);

    m_presenceTimer.setInterval(20000);
    m_presenceTimer.setSingleShot(false);
    connect(&m_presenceTimer, &QTimer::timeout, this, &SocialClient::publishPresence);

    m_messageTimer.setInterval(3500);
    m_messageTimer.setSingleShot(false);
    connect(&m_messageTimer, &QTimer::timeout, this, &SocialClient::refreshMessages);
}

void SocialClient::setServiceUrl(const QString &url)
{
    auto normalized = url.trimmed();
    while (normalized.endsWith(QLatin1Char('/'))) normalized.chop(1);
    if (normalized == m_serviceUrl) return;

    if (!normalized.isEmpty()) {
        const QUrl parsed(normalized, QUrl::StrictMode);
        const auto host = parsed.host().toLower();
        const bool loopback = host == QStringLiteral("localhost")
            || host == QStringLiteral("127.0.0.1") || host == QStringLiteral("::1");
        if (!parsed.isValid() || host.isEmpty()
                || (parsed.scheme() != QStringLiteral("https")
                    && parsed.scheme() != QStringLiteral("http"))
                || (parsed.scheme() == QStringLiteral("http") && !loopback)
                || (!parsed.path().isEmpty() && parsed.path() != QStringLiteral("/"))
                || !parsed.userInfo().isEmpty() || !parsed.query().isEmpty()
                || !parsed.fragment().isEmpty()) {
            setError(tr("Enter an HTTPS service URL (HTTP is allowed only on localhost), without a path or credentials."));
            return;
        }
        normalized = parsed.toString();
        while (normalized.endsWith(QLatin1Char('/'))) normalized.chop(1);
    }

    if (authenticated()) clearSession();
    m_serviceUrl = normalized;
    QSettings().setValue(QStringLiteral("social/serviceUrl"), m_serviceUrl);
    emit serviceUrlChanged();
    setError({});
}

void SocialClient::registerAccount(const QString &user, const QString &password,
                                   const QString &nvidiaDisplayName)
{
    request(QByteArrayLiteral("POST"), QStringLiteral("/v1/auth/register"),
            {{QStringLiteral("username"), user},
             {QStringLiteral("password"), password},
             {QStringLiteral("nvidiaDisplayName"), nvidiaDisplayName}},
            QStringLiteral("register"), [this](const QJsonObject &response) {
        const auto token = response.value(QStringLiteral("token")).toString();
        if (token.isEmpty()) {
            setError(tr("The social service returned an invalid registration response."));
            return;
        }
        const bool wasAuthenticated = authenticated();
        m_token = token;
        setProfile(response.value(QStringLiteral("user")).toObject());
        applyPrivacy(response.value(QStringLiteral("privacy")).toObject());
        if (!wasAuthenticated) emit authenticatedChanged();
        m_refreshTimer.start();
        m_presenceTimer.start();
        refresh();
        publishPresence();
        emit operationFinished(QStringLiteral("register"), true, tr("OpenNOW account created."));
    });
}

void SocialClient::signIn(const QString &user, const QString &password)
{
    request(QByteArrayLiteral("POST"), QStringLiteral("/v1/auth/login"),
            {{QStringLiteral("username"), user}, {QStringLiteral("password"), password}},
            QStringLiteral("sign-in"), [this](const QJsonObject &response) {
        const auto token = response.value(QStringLiteral("token")).toString();
        if (token.isEmpty()) {
            setError(tr("The social service returned an invalid sign-in response."));
            return;
        }
        const bool wasAuthenticated = authenticated();
        m_token = token;
        setProfile(response.value(QStringLiteral("user")).toObject());
        applyPrivacy(response.value(QStringLiteral("privacy")).toObject());
        if (!wasAuthenticated) emit authenticatedChanged();
        m_refreshTimer.start();
        m_presenceTimer.start();
        refresh();
        publishPresence();
        emit operationFinished(QStringLiteral("sign-in"), true, tr("Signed in to OpenNOW Social."));
    });
}

void SocialClient::signOut()
{
    if (!authenticated()) return;
    request(QByteArrayLiteral("POST"), QStringLiteral("/v1/auth/logout"), {}, QStringLiteral("sign-out"));
    clearSession();
}

void SocialClient::refresh()
{
    if (!authenticated()) return;
    request(QByteArrayLiteral("GET"), QStringLiteral("/v1/me"), {}, QStringLiteral("refresh-profile"), [this](const QJsonObject &response) {
        setProfile(response.value(QStringLiteral("user")).toObject());
        applyPrivacy(response.value(QStringLiteral("privacy")).toObject());
    });
    request(QByteArrayLiteral("GET"), QStringLiteral("/v1/friends"), {}, QStringLiteral("refresh-friends"), [this](const QJsonObject &response) {
        m_friends = response.value(QStringLiteral("friends")).toArray().toVariantList();
        emit friendsChanged();
    });
    request(QByteArrayLiteral("GET"), QStringLiteral("/v1/friend-requests"), {}, QStringLiteral("refresh-requests"), [this](const QJsonObject &response) {
        m_friendRequests = response.value(QStringLiteral("requests")).toArray().toVariantList();
        emit friendRequestsChanged();
    });
}

void SocialClient::sendFriendRequest(const QString &identifier)
{
    request(QByteArrayLiteral("POST"), QStringLiteral("/v1/friend-requests"),
            {{QStringLiteral("identifier"), identifier}}, QStringLiteral("friend-request"),
            [this](const QJsonObject &) {
        refresh();
        emit operationFinished(QStringLiteral("friend-request"), true, tr("Friend request sent."));
    });
}

void SocialClient::respondToFriendRequest(const QString &userId, bool accept)
{
    const auto action = accept ? QStringLiteral("accept") : QStringLiteral("reject");
    request(QByteArrayLiteral("POST"), QStringLiteral("/v1/friend-requests/") + userId + QLatin1Char('/') + action,
            {}, QStringLiteral("friend-request-response"), [this, accept](const QJsonObject &) {
        refresh();
        emit operationFinished(QStringLiteral("friend-request-response"), true,
                               accept ? tr("Friend request accepted.") : tr("Friend request declined."));
    });
}

void SocialClient::selectFriend(const QString &userId)
{
    if (userId == m_selectedFriendId) return;
    m_selectedFriendId = userId;
    m_selectedFriendCursor = QStringLiteral("0");
    m_messages.clear();
    emit selectedFriendChanged();
    emit messagesChanged();
    if (m_selectedFriendId.isEmpty() || !authenticated()) {
        m_messageTimer.stop();
        return;
    }
    m_messageTimer.start();
    refreshMessages();
}

void SocialClient::sendMessage(const QString &text)
{
    if (m_selectedFriendId.isEmpty()) {
        setError(tr("Choose a friend before sending a message."));
        return;
    }
    const auto recipientId = m_selectedFriendId;
    const auto path = QStringLiteral("/v1/friends/") + recipientId + QStringLiteral("/messages");
    request(QByteArrayLiteral("POST"), path, {{QStringLiteral("text"), text}}, QStringLiteral("send-message"),
            [this, recipientId](const QJsonObject &response) {
        const auto message = response.value(QStringLiteral("message")).toObject().toVariantMap();
        if (!message.isEmpty() && m_selectedFriendId == recipientId) {
            m_messages.push_back(message);
            bool ok = false;
            const auto id = message.value(QStringLiteral("id")).toString();
            const auto numericId = id.toLongLong(&ok);
            if (!ok) {
                const auto value = message.value(QStringLiteral("id"));
                if (value.canConvert<qlonglong>()) m_selectedFriendCursor = QString::number(value.toLongLong());
            } else {
                m_selectedFriendCursor = QString::number(numericId);
            }
            emit messagesChanged();
        }
        emit operationFinished(QStringLiteral("send-message"), true, tr("Message sent."));
    });
}

void SocialClient::setPrivacy(bool sharePresence, bool shareActivity, bool shareHistory)
{
    request(QByteArrayLiteral("PUT"), QStringLiteral("/v1/privacy"),
            {{QStringLiteral("sharePresence"), sharePresence},
             {QStringLiteral("shareActivity"), shareActivity},
             {QStringLiteral("shareHistory"), shareHistory}},
            QStringLiteral("privacy"), [this](const QJsonObject &response) {
        applyPrivacy(response.value(QStringLiteral("privacy")).toObject());
        emit operationFinished(QStringLiteral("privacy"), true, tr("Privacy settings saved."));
        publishPresence();
        refresh();
    });
}

void SocialClient::setNvidiaDisplayName(const QString &displayName)
{
    request(QByteArrayLiteral("PUT"), QStringLiteral("/v1/profile"),
            {{QStringLiteral("nvidiaDisplayName"), displayName}},
            QStringLiteral("profile"), [this](const QJsonObject &response) {
        setProfile(response.value(QStringLiteral("user")).toObject());
        emit operationFinished(QStringLiteral("profile"), true, tr("Profile saved. NVIDIA display names are not verified by OpenNOW."));
    });
}

void SocialClient::setActivity(const QString &gameId, const QString &gameName)
{
    QJsonObject next;
    if (!gameId.trimmed().isEmpty() && !gameName.trimmed().isEmpty()) {
        next.insert(QStringLiteral("gameId"), gameId.trimmed());
        next.insert(QStringLiteral("gameName"), gameName.trimmed());
    }
    if (next == m_activity) return;
    m_activity = next;
    publishPresence();
}

void SocialClient::clearError()
{
    setError({});
}

void SocialClient::copyFriendCode()
{
    if (QGuiApplication::clipboard() && !friendCode().isEmpty())
        QGuiApplication::clipboard()->setText(friendCode());
}

void SocialClient::request(const QByteArray &method, const QString &path,
                           const QJsonObject &body, const QString &operation,
                           Callback callback)
{
    if (m_serviceUrl.isEmpty()) {
        setError(tr("Set the public OpenNOW Social service URL first."));
        emit operationFinished(operation, false, m_error);
        return;
    }
    const bool authRoute = path == QStringLiteral("/v1/auth/register")
        || path == QStringLiteral("/v1/auth/login");
    if (!authRoute && !authenticated()) {
        setError(tr("Sign in to your OpenNOW Social account first."));
        emit operationFinished(operation, false, m_error);
        return;
    }

    QNetworkRequest networkRequest(QUrl(m_serviceUrl + path, QUrl::StrictMode));
    networkRequest.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    networkRequest.setRawHeader(QByteArrayLiteral("Accept"), QByteArrayLiteral("application/json"));
    networkRequest.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                                QNetworkRequest::NoLessSafeRedirectPolicy);
    networkRequest.setTransferTimeout(15000);
    if (!m_token.isEmpty())
        networkRequest.setRawHeader("Authorization", QByteArrayLiteral("Bearer ") + m_token.toUtf8());

    QNetworkReply *reply = nullptr;
    if (method == QByteArrayLiteral("GET")) {
        reply = m_network.get(networkRequest);
    } else if (method == QByteArrayLiteral("DELETE")) {
        reply = m_network.deleteResource(networkRequest);
    } else {
        const auto payload = QJsonDocument(body).toJson(QJsonDocument::Compact);
        reply = m_network.sendCustomRequest(networkRequest, method, payload);
    }

    const bool wasBusy = busy();
    ++m_pendingRequests;
    if (!wasBusy) emit busyChanged();
    connect(reply, &QNetworkReply::finished, this, [this, reply, operation, callback = std::move(callback)] {
        const auto bytes = reply->readAll();
        const auto document = QJsonDocument::fromJson(bytes);
        const auto response = document.isObject() ? document.object() : QJsonObject{};
        const auto status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const auto networkError = reply->error();
        const auto networkMessage = reply->errorString();
        reply->deleteLater();
        const bool wasBusy = busy();
        m_pendingRequests = qMax(0, m_pendingRequests - 1);
        if (wasBusy != busy()) emit busyChanged();

        if (networkError != QNetworkReply::NoError || status < 200 || status >= 300) {
            QString message = response.value(QStringLiteral("error")).toString();
            if (message.isEmpty()) message = status > 0
                ? tr("OpenNOW Social returned HTTP %1.").arg(status)
                : tr("Could not reach the OpenNOW Social service: %1").arg(networkMessage);
            if (status == 401 && authenticated()) clearSession();
            setError(message);
            emit operationFinished(operation, false, message);
            return;
        }
        if (callback) callback(response);
        if (operation != QStringLiteral("refresh-profile")
                && operation != QStringLiteral("refresh-friends")
                && operation != QStringLiteral("refresh-requests")
                && operation != QStringLiteral("refresh-messages"))
            setError({});
        if (operation == QStringLiteral("sign-out"))
            emit operationFinished(operation, true, tr("Signed out."));
    });
}

void SocialClient::setError(const QString &value)
{
    if (m_error == value) return;
    m_error = value;
    emit errorChanged();
}

void SocialClient::setProfile(const QJsonObject &profileValue)
{
    const auto next = profileValue.toVariantMap();
    if (m_profile == next) return;
    m_profile = next;
    emit profileChanged();
}

void SocialClient::applyPrivacy(const QJsonObject &privacyValue)
{
    const auto next = privacyValue.toVariantMap();
    if (m_privacy == next) return;
    m_privacy = next;
    emit privacyChanged();
}

void SocialClient::publishPresence()
{
    if (!authenticated()) return;
    const auto privacyAllowsTracking = m_privacy.value(QStringLiteral("shareActivity")).toBool()
        || m_privacy.value(QStringLiteral("shareHistory")).toBool();
    const auto sharedActivity = privacyAllowsTracking ? QJsonValue(m_activity)
                                                      : QJsonValue(QJsonValue::Null);
    request(QByteArrayLiteral("PUT"), QStringLiteral("/v1/presence"),
            {{QStringLiteral("status"), QStringLiteral("online")},
             {QStringLiteral("activity"), sharedActivity}},
            QStringLiteral("presence"));
}

void SocialClient::refreshMessages()
{
    if (!authenticated() || m_selectedFriendId.isEmpty()) return;
    const auto path = QStringLiteral("/v1/friends/") + m_selectedFriendId
        + QStringLiteral("/messages?after=") + m_selectedFriendCursor;
    const auto expectedFriend = m_selectedFriendId;
    request(QByteArrayLiteral("GET"), path, {}, QStringLiteral("refresh-messages"), [this, expectedFriend](const QJsonObject &response) {
        if (m_selectedFriendId != expectedFriend) return;
        const auto received = response.value(QStringLiteral("messages")).toArray().toVariantList();
        if (received.isEmpty()) return;
        for (const auto &item : received) {
            const auto message = item.toMap();
            const auto id = message.value(QStringLiteral("id")).toLongLong();
            bool cursorOk = false;
            const auto current = m_selectedFriendCursor.toLongLong(&cursorOk);
            if (!cursorOk || id > current) m_selectedFriendCursor = QString::number(id);
            m_messages.push_back(message);
        }
        while (m_messages.size() > 300) m_messages.removeFirst();
        emit messagesChanged();
    });
}

void SocialClient::clearSession()
{
    const bool wasAuthenticated = authenticated();
    m_token.clear();
    m_refreshTimer.stop();
    m_presenceTimer.stop();
    m_messageTimer.stop();
    m_profile.clear();
    m_privacy.clear();
    m_friends.clear();
    m_friendRequests.clear();
    m_messages.clear();
    m_selectedFriendId.clear();
    m_selectedFriendCursor = QStringLiteral("0");
    m_activity = {};
    if (wasAuthenticated) emit authenticatedChanged();
    emit profileChanged();
    emit privacyChanged();
    emit friendsChanged();
    emit friendRequestsChanged();
    emit messagesChanged();
    emit selectedFriendChanged();
}
