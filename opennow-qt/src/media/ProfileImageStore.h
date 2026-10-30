#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>

class ProfileImageStore final : public QObject
{
    Q_OBJECT

public:
    explicit ProfileImageStore(QObject *parent = nullptr);

    // Imports a local image as a center-cropped square PNG in OpenNOW's data
    // directory. The returned URL changes with the content, so QML never keeps
    // displaying a stale cached avatar after a replacement.
    Q_INVOKABLE QVariantMap importImage(const QString &urlOrPath, int targetSize = 256) const;

    // Extracts a dominant, visibly saturated color without retaining or
    // modifying the source image. Used to derive an accent from local wallpaper.
    Q_INVOKABLE QVariantMap dominantColor(const QString &urlOrPath) const;
};
