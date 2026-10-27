#include <QCoreApplication>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QThread>

#include <cstdlib>
#include <iostream>
#include <string>

using namespace Qt::StringLiterals;

namespace {
void writeMessage(const QJsonObject &message)
{
    std::cout << QJsonDocument(message).toJson(QJsonDocument::Compact).constData() << '\n';
    std::cout.flush();
}
}

int main(int argc, char **argv)
{
    QCoreApplication application(argc, argv);
    QFile log(qEnvironmentVariable("OPENNOW_FAKE_STREAMER_LOG"));
    if (!log.fileName().isEmpty())
        log.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text);
    QString sessionStartId;

    std::string input;
    while (std::getline(std::cin, input)) {
        const auto command = QJsonDocument::fromJson(QByteArray::fromStdString(input)).object();
        const auto id = command.value(u"id"_s).toString();
        const auto type = command.value(u"type"_s).toString();
        if (log.isOpen()) {
            const QJsonObject record{
                {u"command"_s, command},
                {u"externalRenderer"_s, qEnvironmentVariable("OPENNOW_NATIVE_EXTERNAL_RENDERER")},
                {u"inputOwner"_s, qEnvironmentVariable("OPENNOW_NATIVE_INPUT_OWNER")},
                {u"standalone"_s, qEnvironmentVariable("OPENNOW_NATIVE_STANDALONE_WINDOW")},
                {u"windowsApi"_s, qEnvironmentVariable("OPENNOW_NATIVE_WINDOWS_API")},
                {u"videoBackend"_s, qEnvironmentVariable("OPENNOW_NATIVE_VIDEO_BACKEND")},
            };
            log.write(QJsonDocument(record).toJson(QJsonDocument::Compact) + '\n');
            log.flush();
        }

        if (type == u"crash"_s) std::_Exit(17);
        if (type == u"shutdown"_s) {
            writeMessage(QJsonObject{{u"id"_s, id}, {u"type"_s, u"ok"_s}});
            if (qEnvironmentVariable("OPENNOW_FAKE_STREAMER_HANG_SHUTDOWN") == u"1"_s)
                QThread::sleep(30);
            return 0;
        }

        if (type == u"hello"_s) {
            writeMessage(QJsonObject{
                {u"id"_s, id},
                {u"type"_s, u"ready"_s},
                {u"capabilities"_s, QJsonObject{
                    {u"protocolVersion"_s, 7},
                    {u"backend"_s, u"fake-sidecar"_s},
                    {u"supportsInput"_s, true},
                    {u"supportsVideoDecode"_s, true},
                    {u"supportsVideoPresent"_s, true},
                    {u"supportsAudioDecode"_s, true},
                    {u"supportsAudioOutput"_s, true},
                }},
            });
            continue;
        }

        if (type == u"start"_s) {
            sessionStartId = id;
            writeMessage(QJsonObject{
                {u"id"_s, id}, {u"type"_s, u"ok"_s}, {u"transport"_s, u"nvst"_s}});
            writeMessage(QJsonObject{
                {u"type"_s, u"status"_s}, {u"status"_s, u"connecting"_s},
                {u"startId"_s, sessionStartId}});
            writeMessage(QJsonObject{
                {u"type"_s, u"status"_s}, {u"status"_s, u"streaming"_s},
                {u"startId"_s, sessionStartId}});
            writeMessage(QJsonObject{
                {u"type"_s, u"telemetry"_s}, {u"startId"_s, sessionStartId},
                {u"decodeProgressStage"_s, u"tracking"_s},
                {u"decodeTimings"_s, QJsonObject{
                    {u"epoch"_s, 7}, {u"outputsTotal"_s, 42},
                }},
            });
            continue;
        }

        if (type == u"stop"_s) {
            // The real engine queues its terminal event before the correlated
            // stop response. Preserve that ordering in this asynchronous fake.
            writeMessage(QJsonObject{
                {u"type"_s, u"status"_s}, {u"status"_s, u"stopped"_s},
                {u"startId"_s, sessionStartId}});
            sessionStartId.clear();
        }
        writeMessage(QJsonObject{{u"id"_s, id}, {u"type"_s, u"ok"_s}});
    }
    return 0;
}
