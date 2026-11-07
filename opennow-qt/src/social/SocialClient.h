#pragma once

#include <QObject>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

#include <functional>

class QNetworkReply;

class SocialClient final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString serviceUrl READ serviceUrl WRITE setServiceUrl NOTIFY serviceUrlChanged)
    Q_PROPERTY(bool authenticated READ authenticated NOTIFY authenticatedChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString username READ username NOTIFY profileChanged)
    Q_PROPERTY(QString displayName READ displayName NOTIFY profileChanged)
    Q_PROPERTY(QString friendCode READ friendCode NOTIFY profileChanged)
    Q_PROPERTY(QVariantMap profile READ profile NOTIFY profileChanged)
    Q_PROPERTY(QVariantMap privacy READ privacy NOTIFY privacyChanged)
    Q_PROPERTY(QVariantList friends READ friends NOTIFY friendsChanged)
    Q_PROPERTY(QVariantList friendRequests READ friendRequests NOTIFY friendRequestsChanged)
    Q_PROPERTY(QVariantList messages READ messages NOTIFY messagesChanged)
    Q_PROPERTY(QString selectedFriendId READ selectedFriendId NOTIFY selectedFriendChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)

public:
    explicit SocialClient(QObject *parent = nullptr);

    QString serviceUrl() const { return m_serviceUrl; }
    bool authenticated() const { return !m_token.isEmpty(); }
    bool busy() const { return m_pendingRequests > 0; }
    QString username() const { return m_profile.value(QStringLiteral("username")).toString(); }
    QString displayName() const { return m_profile.value(QStringLiteral("displayName")).toString(); }
    QString friendCode() const { return m_profile.value(QStringLiteral("friendCode")).toString(); }
    QVariantMap profile() const { return m_profile; }
    QVariantMap privacy() const { return m_privacy; }
    QVariantList friends() const { return m_friends; }
    QVariantList friendRequests() const { return m_friendRequests; }
    QVariantList messages() const { return m_messages; }
    QString selectedFriendId() const { return m_selectedFriendId; }
    QString error() const { return m_error; }

    void setServiceUrl(const QString &url);

    Q_INVOKABLE void registerAccount(const QString &username, const QString &password,
                                     const QString &nvidiaDisplayName = {});
    Q_INVOKABLE void signIn(const QString &username, const QString &password);
    Q_INVOKABLE void signOut();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void sendFriendRequest(const QString &identifier);
    Q_INVOKABLE void respondToFriendRequest(const QString &userId, bool accept);
    Q_INVOKABLE void selectFriend(const QString &userId);
    Q_INVOKABLE void sendMessage(const QString &text);
    Q_INVOKABLE void setPrivacy(bool sharePresence, bool shareActivity, bool shareHistory);
    Q_INVOKABLE void setNvidiaDisplayName(const QString &displayName);
    Q_INVOKABLE void setActivity(const QString &gameId, const QString &gameName);
    Q_INVOKABLE void clearError();
    Q_INVOKABLE void copyFriendCode();

signals:
    void serviceUrlChanged();
    void authenticatedChanged();
    void busyChanged();
    void profileChanged();
    void privacyChanged();
    void friendsChanged();
    void friendRequestsChanged();
    void messagesChanged();
    void selectedFriendChanged();
    void errorChanged();
    void operationFinished(const QString &operation, bool success, const QString &message);

private:
    using Callback = std::function<void(const QJsonObject &)>;
    void request(const QByteArray &method, const QString &path, const QJsonObject &body,
                 const QString &operation, Callback callback = {});
    void setError(const QString &error);
    void setProfile(const QJsonObject &profile);
    void applyPrivacy(const QJsonObject &privacy);
    void publishPresence();
    void refreshMessages();
    void clearSession();

    QNetworkAccessManager m_network;
    QTimer m_refreshTimer;
    QTimer m_presenceTimer;
    QTimer m_messageTimer;
    QString m_serviceUrl;
    QString m_token;
    QString m_error;
    QString m_selectedFriendId;
    QString m_selectedFriendCursor;
    int m_pendingRequests = 0;
    QVariantMap m_profile;
    QVariantMap m_privacy;
    QVariantList m_friends;
    QVariantList m_friendRequests;
    QVariantList m_messages;
    QJsonObject m_activity;
};
