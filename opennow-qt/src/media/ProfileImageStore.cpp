#include "media/ProfileImageStore.h"

#include <QBuffer>
#include <QColor>
#include <QCryptographicHash>
#include <QDir>
#include <QFileInfo>
#include <QImage>
#include <QImageReader>
#include <QSaveFile>
#include <QStandardPaths>
#include <QStringList>
#include <QRect>
#include <QUrl>

#include <array>
#include <cmath>

using namespace Qt::StringLiterals;

namespace {
QVariantMap failure(const QString &code)
{
    return {{u"ok"_s, false}, {u"error"_s, code}};
}

QString storageDirectory()
{
    if (qEnvironmentVariableIsSet("OPENNOW_PROFILE_IMAGE_DIR")) {
        const auto overridePath = qEnvironmentVariable("OPENNOW_PROFILE_IMAGE_DIR");
        return overridePath.isEmpty() ? QString{}
            : QDir::cleanPath(QFileInfo(overridePath).absoluteFilePath());
    }
    const auto base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    return base.isEmpty() ? QString{} : QDir(base).filePath(u"profile-images"_s);
}
}

ProfileImageStore::ProfileImageStore(QObject *parent)
    : QObject(parent)
{
}

QVariantMap ProfileImageStore::importImage(const QString &urlOrPath, int targetSize) const
{
    if (targetSize != 128 && targetSize != 256 && targetSize != 512)
        return failure(u"invalid-size"_s);

    const QUrl url(urlOrPath);
    const QFileInfo source(url.isLocalFile() ? url.toLocalFile() : urlOrPath);
    if (!source.isAbsolute() || !source.isFile() || source.size() <= 0)
        return failure(u"invalid-source"_s);
    if (source.size() > 20LL * 1024 * 1024)
        return failure(u"file-too-large"_s);
    const auto extension = source.suffix().toLower();
    if (!QStringList{u"png"_s, u"jpg"_s, u"jpeg"_s, u"webp"_s, u"bmp"_s}.contains(extension))
        return failure(u"unsupported-type"_s);

    QImageReader reader(source.absoluteFilePath());
    reader.setAutoTransform(true);
    auto image = reader.read();
    if (image.isNull())
        return failure(u"decode-failed"_s);
    const auto sourceWidth = image.width();
    const auto sourceHeight = image.height();
    if (sourceWidth < 64 || sourceHeight < 64 || sourceWidth > 4096 || sourceHeight > 4096)
        return failure(u"invalid-dimensions"_s);

    const auto side = qMin(sourceWidth, sourceHeight);
    const QRect crop((sourceWidth - side) / 2, (sourceHeight - side) / 2, side, side);
    auto avatar = image.copy(crop).scaled(targetSize, targetSize, Qt::IgnoreAspectRatio,
        Qt::SmoothTransformation).convertToFormat(QImage::Format_ARGB32_Premultiplied);
    if (avatar.isNull())
        return failure(u"decode-failed"_s);

    QByteArray encoded;
    QBuffer buffer(&encoded);
    if (!buffer.open(QIODevice::WriteOnly) || !avatar.save(&buffer, "PNG"))
        return failure(u"encode-failed"_s);
    buffer.close();

    const auto directoryPath = storageDirectory();
    if (directoryPath.isEmpty() || !QDir().mkpath(directoryPath))
        return failure(u"storage-unavailable"_s);
    const auto digest = QCryptographicHash::hash(encoded, QCryptographicHash::Sha256).toHex().left(24);
    const auto outputPath = QDir(directoryPath).filePath(
        u"avatar-%1-%2.png"_s.arg(QString::fromLatin1(digest)).arg(targetSize));
    if (!QFileInfo::exists(outputPath)) {
        QSaveFile output(outputPath);
        if (!output.open(QIODevice::WriteOnly) || output.write(encoded) != encoded.size()
                || !output.commit()) {
            output.cancelWriting();
            return failure(u"save-failed"_s);
        }
    }

    return {
        {u"ok"_s, true},
        {u"error"_s, QString{}},
        {u"url"_s, QUrl::fromLocalFile(outputPath).toString()},
        {u"width"_s, targetSize},
        {u"height"_s, targetSize},
        {u"sourceWidth"_s, sourceWidth},
        {u"sourceHeight"_s, sourceHeight},
    };
}

QVariantMap ProfileImageStore::dominantColor(const QString &urlOrPath) const
{
    const QUrl url(urlOrPath);
    const QFileInfo source(url.isLocalFile() ? url.toLocalFile() : urlOrPath);
    if (!source.isAbsolute() || !source.isFile() || source.size() <= 0)
        return failure(u"invalid-source"_s);
    if (source.size() > 20LL * 1024 * 1024)
        return failure(u"file-too-large"_s);
    const auto extension = source.suffix().toLower();
    if (!QStringList{u"png"_s, u"jpg"_s, u"jpeg"_s, u"webp"_s, u"bmp"_s}.contains(extension))
        return failure(u"unsupported-type"_s);

    QImageReader reader(source.absoluteFilePath());
    reader.setAutoTransform(true);
    const auto image = reader.read();
    if (image.isNull())
        return failure(u"decode-failed"_s);
    if (image.width() < 64 || image.height() < 64 || image.width() > 4096 || image.height() > 4096)
        return failure(u"invalid-dimensions"_s);

    const auto sample = image.scaled(48, 48, Qt::IgnoreAspectRatio, Qt::SmoothTransformation)
        .convertToFormat(QImage::Format_ARGB32);
    std::array<double, 4096> weights{};
    std::array<double, 4096> red{};
    std::array<double, 4096> green{};
    std::array<double, 4096> blue{};
    for (int y = 0; y < sample.height(); ++y) {
        for (int x = 0; x < sample.width(); ++x) {
            const auto pixel = sample.pixelColor(x, y);
            if (pixel.alpha() < 128) continue;
            const int r = pixel.red();
            const int g = pixel.green();
            const int b = pixel.blue();
            const int maximum = qMax(r, qMax(g, b));
            const int minimum = qMin(r, qMin(g, b));
            const double saturation = maximum == 0 ? 0.0
                : static_cast<double>(maximum - minimum) / maximum;
            const double lightness = static_cast<double>(maximum + minimum) / 510.0;
            const double weight = (0.05 + saturation * saturation)
                * (0.5 + 0.5 * (1.0 - std::abs(lightness * 2.0 - 1.0)));
            const int bucket = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
            weights[bucket] += weight;
            red[bucket] += r * weight;
            green[bucket] += g * weight;
            blue[bucket] += b * weight;
        }
    }

    int best = -1;
    for (int index = 0; index < static_cast<int>(weights.size()); ++index) {
        if (weights[index] > 0 && (best < 0 || weights[index] > weights[best])) best = index;
    }
    if (best < 0)
        return failure(u"no-visible-pixels"_s);
    const auto average = [best, &weights](const std::array<double, 4096> &channel) {
        return qBound(0, static_cast<int>(std::lround(channel[best] / weights[best])), 255);
    };
    return {
        {u"ok"_s, true},
        {u"error"_s, QString{}},
        {u"color"_s, QColor(average(red), average(green), average(blue)).name(QColor::HexRgb)},
    };
}
