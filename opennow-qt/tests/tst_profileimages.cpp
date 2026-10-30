#include "media/ProfileImageStore.h"

#include <QColor>
#include <QDir>
#include <QFile>
#include <QImage>
#include <QScopeGuard>
#include <QTemporaryDir>
#include <QUrl>
#include <QtTest>

class ProfileImageStoreTest final : public QObject
{
    Q_OBJECT

private slots:
    void importsCenterCroppedPngAtRequestedDimensions();
    void rejectsInvalidSourcesAndDimensions();
    void extractsDominantColorFromLocalImages();

private:
    QByteArray previousDirectory;
    bool hadDirectory = false;

    void installTemporaryDirectory(const QString &path)
    {
        hadDirectory = qEnvironmentVariableIsSet("OPENNOW_PROFILE_IMAGE_DIR");
        previousDirectory = qgetenv("OPENNOW_PROFILE_IMAGE_DIR");
        qputenv("OPENNOW_PROFILE_IMAGE_DIR", path.toUtf8());
    }

    void restoreDirectory()
    {
        if (hadDirectory) qputenv("OPENNOW_PROFILE_IMAGE_DIR", previousDirectory);
        else qunsetenv("OPENNOW_PROFILE_IMAGE_DIR");
    }

    static QString writeImage(const QString &path, const QSize &size)
    {
        QImage image(size, QImage::Format_ARGB32);
        image.fill(Qt::transparent);
        for (int y = 0; y < image.height(); ++y) {
            for (int x = 0; x < image.width(); ++x)
                image.setPixelColor(x, y, x < image.width() / 2 ? QColor("#E63946") : QColor("#457B9D"));
        }
        return image.save(path, "PNG") ? path : QString{};
    }
};

void ProfileImageStoreTest::importsCenterCroppedPngAtRequestedDimensions()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    installTemporaryDirectory(directory.path());
    const auto restore = qScopeGuard([this] { restoreDirectory(); });
    const auto source = writeImage(directory.filePath(QStringLiteral("wide.png")), QSize(160, 100));
    QVERIFY(!source.isEmpty());

    ProfileImageStore store;
    const auto imported = store.importImage(QUrl::fromLocalFile(source).toString(), 128);
    QCOMPARE(imported.value(QStringLiteral("ok")).toBool(), true);
    QCOMPARE(imported.value(QStringLiteral("width")).toInt(), 128);
    QCOMPARE(imported.value(QStringLiteral("height")).toInt(), 128);
    QCOMPARE(imported.value(QStringLiteral("sourceWidth")).toInt(), 160);
    QCOMPARE(imported.value(QStringLiteral("sourceHeight")).toInt(), 100);
    const auto output = QUrl(imported.value(QStringLiteral("url")).toString()).toLocalFile();
    QVERIFY(output.startsWith(directory.path()));
    QImage avatar(output);
    QCOMPARE(avatar.size(), QSize(128, 128));
    QCOMPARE(avatar.pixelColor(8, 64), QColor("#E63946"));
    QCOMPARE(avatar.pixelColor(120, 64), QColor("#457B9D"));

    const auto repeated = store.importImage(source, 128);
    QCOMPARE(repeated.value(QStringLiteral("url")), imported.value(QStringLiteral("url")));
    const auto larger = store.importImage(source, 256);
    QCOMPARE(larger.value(QStringLiteral("ok")).toBool(), true);
    QVERIFY(larger.value(QStringLiteral("url")) != imported.value(QStringLiteral("url")));
    QCOMPARE(QImage(QUrl(larger.value(QStringLiteral("url")).toString()).toLocalFile()).size(),
        QSize(256, 256));
    QVERIFY(QFile::remove(source));
    QCOMPARE(QImage(output).size(), QSize(128, 128));
}

void ProfileImageStoreTest::rejectsInvalidSourcesAndDimensions()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    installTemporaryDirectory(directory.path());
    const auto restore = qScopeGuard([this] { restoreDirectory(); });
    ProfileImageStore store;
    QCOMPARE(store.importImage(directory.filePath(QStringLiteral("missing.png"))).value(
        QStringLiteral("error")).toString(), QStringLiteral("invalid-source"));
    QCOMPARE(store.importImage(directory.filePath(QStringLiteral("wide.png")), 1024).value(
        QStringLiteral("error")).toString(), QStringLiteral("invalid-size"));

    const auto tiny = writeImage(directory.filePath(QStringLiteral("tiny.png")), QSize(32, 64));
    QVERIFY(!tiny.isEmpty());
    QCOMPARE(store.importImage(tiny).value(QStringLiteral("error")).toString(),
        QStringLiteral("invalid-dimensions"));
    const auto wide = writeImage(directory.filePath(QStringLiteral("too-wide.png")), QSize(5000, 64));
    QVERIFY(!wide.isEmpty());
    QCOMPARE(store.importImage(wide).value(QStringLiteral("error")).toString(),
        QStringLiteral("invalid-dimensions"));

    const auto unsupported = directory.filePath(QStringLiteral("avatar.txt"));
    QFile text(unsupported);
    QVERIFY(text.open(QIODevice::WriteOnly));
    QCOMPARE(text.write("not an image"), 12);
    text.close();
    QCOMPARE(store.importImage(unsupported).value(QStringLiteral("error")).toString(),
        QStringLiteral("unsupported-type"));
    const auto corrupt = directory.filePath(QStringLiteral("corrupt.png"));
    QVERIFY(QFile::copy(unsupported, corrupt));
    QCOMPARE(store.importImage(corrupt).value(QStringLiteral("error")).toString(),
        QStringLiteral("decode-failed"));
}

void ProfileImageStoreTest::extractsDominantColorFromLocalImages()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    ProfileImageStore store;
    const auto source = directory.filePath(QStringLiteral("wallpaper.png"));
    QImage image(QSize(64, 64), QImage::Format_ARGB32);
    image.fill(QColor("#E63946"));
    QVERIFY(image.save(source, "PNG"));

    const auto extracted = store.dominantColor(QUrl::fromLocalFile(source).toString());
    QCOMPARE(extracted.value(QStringLiteral("ok")).toBool(), true);
    QCOMPARE(extracted.value(QStringLiteral("color")).toString(), QStringLiteral("#e63946"));
    QCOMPARE(store.dominantColor(QStringLiteral("https://example.com/wallpaper.png"))
        .value(QStringLiteral("error")).toString(), QStringLiteral("invalid-source"));

    image.fill(Qt::transparent);
    QVERIFY(image.save(source, "PNG"));
    QCOMPARE(store.dominantColor(source).value(QStringLiteral("error")).toString(),
        QStringLiteral("no-visible-pixels"));
}

QTEST_MAIN(ProfileImageStoreTest)
#include "tst_profileimages.moc"
