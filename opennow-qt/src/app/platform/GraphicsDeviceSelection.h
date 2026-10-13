#pragma once

#include <QList>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>

class QQuickWindow;

class GraphicsDeviceSelection final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool selectorVisible READ selectorVisible CONSTANT)
    Q_PROPERTY(QVariantList choices READ choices NOTIFY choicesChanged)
    Q_PROPERTY(bool savedDeviceUnavailable READ savedDeviceUnavailable CONSTANT)

public:
    struct Adapter {
        QString id;
        QString name;
        quint64 luid = 0;
        quint64 dedicatedMemoryBytes = 0;
        bool software = false;
        // Hardware decode profiles from ID3D11VideoDevice. These match the
        // streamer's adapter index (H.264, HEVC Main/Main10, AV1 profile 0).
        bool h264 = false;
        bool h265 = false;
        bool av1 = false;
        // D3D_FEATURE_LEVEL reported by D3D11CreateDevice for this adapter, or 0 when the device
        // could not be created and the level is unknown. Feature levels 10_0 (0xa000) and 10_1
        // (0xa100) are DirectX 10 class hardware: they decode H.264 through DXVA but have no
        // Shader Model 5.0 and no D3D11 video processor.
        quint32 featureLevel = 0;
    };

    static QList<Adapter> detectAdapters();
    /// Whether the adapter reports a known DirectX 10 feature level (10_0 or 10_1).
    static bool isDirect3D10Adapter(const Adapter &adapter);
    /// Whether Qt Quick can render this adapter with its Direct3D 11 RHI, which needs Shader
    /// Model 5.0. An adapter whose feature level could not be determined is assumed capable so a
    /// transient enumeration failure never forces the software rasterizer.
    static bool supportsAcceleratedShell(const Adapter &adapter);
    /// Whether any enumerated adapter can run the accelerated shell. Empty results and unknown
    /// feature levels both count as capable: only a machine whose every GPU is DirectX 10 class
    /// should be switched to the Windows software rasterizer on purpose.
    static bool anySupportsAcceleratedShell(const QList<Adapter> &adapters);
    GraphicsDeviceSelection(QList<Adapter> adapters, QString requestedDeviceId,
                            QObject *parent = nullptr);

    bool selectorVisible() const { return m_adapters.size() >= 2; }
    QVariantList choices() const;
    QString requestedDeviceId() const { return m_requestedDeviceId; }
    QString activeDeviceId() const { return m_active.id; }
    bool savedDeviceUnavailable() const;
    quint64 adapterLuid() const { return m_active.luid; }
    bool applyTo(QQuickWindow *window) const;

signals:
    void choicesChanged();

private:
    const Adapter *automaticAdapter() const;
    bool canDecode(const Adapter &adapter) const;
    QStringList codecIds(const Adapter &adapter) const;
    QString codecSummary(const Adapter &adapter) const;
    QString memorySummary(const Adapter &adapter) const;
    QString adapterDetail(const Adapter &adapter) const;

    QList<Adapter> m_adapters;
    QString m_requestedDeviceId;
    Adapter m_active;
};
