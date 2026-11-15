#include "desktop/Wallpaper.h"

#include <QDir>
#include <QFutureWatcher>
#include <QGuiApplication>
#include <QImage>
#include <QPainter>
#include <QProcess>
#include <QScreen>
#include <QStandardPaths>
#include <QTimer>
#include <QtConcurrent>

namespace {

constexpr int kDownscale = 4;    // блюрим в 1/4 разрешения — быстро и всё равно мягко
constexpr int kBlurRadius = 9;   // ≈36 px на полном разрешении
constexpr int kBlurPasses = 3;   // три box-блюра ≈ гаусс

QString xfconfValue(const QString &property)
{
    QProcess p;
    p.start(QStringLiteral("xfconf-query"), {QStringLiteral("-c"), QStringLiteral("xfce4-desktop"),
                                             QStringLiteral("-p"), property});
    if (!p.waitForFinished(1500) || p.exitCode() != 0)
        return {};
    return QString::fromUtf8(p.readAllStandardOutput()).trimmed();
}

// Один проход box-блюра по горизонтали или вертикали (бегущая сумма).
void boxBlurPass(QImage &img, int r, bool horizontal)
{
    const int w = img.width(), h = img.height();
    const int len = horizontal ? w : h;
    const int lines = horizontal ? h : w;
    QList<QRgb> buf(len);

    for (int line = 0; line < lines; ++line) {
        auto px = [&](int i) -> QRgb & {
            return horizontal ? reinterpret_cast<QRgb *>(img.scanLine(line))[i]
                              : reinterpret_cast<QRgb *>(img.scanLine(i))[line];
        };
        for (int i = 0; i < len; ++i)
            buf[i] = px(i);

        int sr = 0, sg = 0, sb = 0;
        const int window = 2 * r + 1;
        for (int k = -r; k <= r; ++k) {
            const QRgb c = buf[std::clamp(k, 0, len - 1)];
            sr += qRed(c); sg += qGreen(c); sb += qBlue(c);
        }
        for (int i = 0; i < len; ++i) {
            px(i) = qRgb(sr / window, sg / window, sb / window);
            const QRgb out = buf[std::clamp(i - r, 0, len - 1)];
            const QRgb in = buf[std::clamp(i + r + 1, 0, len - 1)];
            sr += qRed(in) - qRed(out);
            sg += qGreen(in) - qGreen(out);
            sb += qBlue(in) - qBlue(out);
        }
    }
}

QImage composeBlurred(const QString &path, int style, QSize screen)
{
    if (screen.isEmpty())
        screen = QSize(1920, 1080);
    const QSize out(std::max(1, screen.width() / kDownscale), std::max(1, screen.height() / kDownscale));

    QImage canvas(out, QImage::Format_RGB32);
    canvas.fill(Qt::black);

    QImage img;
    if (style != 0 && !path.isEmpty())
        img.load(path);

    if (!img.isNull()) {
        QPainter p(&canvas);
        p.setRenderHint(QPainter::SmoothPixmapTransform);
        p.scale(1.0 / kDownscale, 1.0 / kDownscale);

        const QSizeF full = screen;
        const QSizeF isz = img.size();
        QRectF target;
        switch (style) {
        case 1: // по центру
            target = QRectF(QPointF((full.width() - isz.width()) / 2, (full.height() - isz.height()) / 2), isz);
            break;
        case 2: // плиткой
            // QPixmap нельзя трогать вне главного потока, плитка через кисть из QImage.
            p.fillRect(QRectF(QPointF(0, 0), full), QBrush(img));
            break;
        case 3: // растянуть
            target = QRectF(QPointF(0, 0), full);
            break;
        case 4: { // вписать
            const qreal s = std::min(full.width() / isz.width(), full.height() / isz.height());
            const QSizeF sz = isz * s;
            target = QRectF(QPointF((full.width() - sz.width()) / 2, (full.height() - sz.height()) / 2), sz);
            break;
        }
        default: { // 5 заполнить, 6 на все экраны — обрезка с заполнением
            const qreal s = std::max(full.width() / isz.width(), full.height() / isz.height());
            const QSizeF sz = isz * s;
            target = QRectF(QPointF((full.width() - sz.width()) / 2, (full.height() - sz.height()) / 2), sz);
            break;
        }
        }
        if (style != 2)
            p.drawImage(target, img);
    }

    for (int i = 0; i < kBlurPasses; ++i) {
        boxBlurPass(canvas, kBlurRadius, true);
        boxBlurPass(canvas, kBlurRadius, false);
    }
    return canvas;
}

} // namespace

Wallpaper::Wallpaper(QObject *parent)
    : QObject(parent)
{
    connect(qGuiApp, &QGuiApplication::screenAdded, this, &Wallpaper::reload);
    connect(qGuiApp, &QGuiApplication::screenRemoved, this, &Wallpaper::reload);
    reload();
    startMonitor();
}

Wallpaper::~Wallpaper()
{
    if (m_monitor) {
        m_monitor->disconnect(this);
        m_monitor->kill();
        m_monitor->waitForFinished(300);
    }
}

QUrl Wallpaper::blurredFor(const QString &screenName) const
{
    if (m_blurred.contains(screenName))
        return m_blurred.value(screenName);
    return m_blurred.isEmpty() ? QUrl() : m_blurred.begin().value();
}

QList<Wallpaper::Source> Wallpaper::readXfceSources() const
{
    QList<Source> list;
    const auto screens = QGuiApplication::screens();
    for (QScreen *screen : screens) {
        const QString prefix = QStringLiteral("/backdrop/screen0/monitor%1/workspace0/").arg(screen->name());
        Source s;
        s.screenName = screen->name();
        s.screenSize = screen->size();
        s.imagePath = xfconfValue(prefix + QStringLiteral("last-image"));
        bool ok = false;
        const int style = xfconfValue(prefix + QStringLiteral("image-style")).toInt(&ok);
        s.style = ok ? style : 5;
        list.append(s);
    }
    return list;
}

void Wallpaper::reload()
{
    const int generation = ++m_generation;
    const QList<Source> sources = readXfceSources();
    const QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    QDir().mkpath(cacheDir);

    auto *watcher = new QFutureWatcher<QHash<QString, QUrl>>(this);
    connect(watcher, &QFutureWatcher<QHash<QString, QUrl>>::finished, this, [this, watcher, generation] {
        watcher->deleteLater();
        if (generation != m_generation)
            return; // пока считали, обои успели смениться ещё раз
        m_blurred = watcher->result();
        ++m_revision;
        emit changed();
    });

    watcher->setFuture(QtConcurrent::run([sources, cacheDir, generation] {
        QHash<QString, QUrl> result;
        for (const Source &s : sources) {
            const QImage img = composeBlurred(s.imagePath, s.style, s.screenSize);
            const QString file = QStringLiteral("%1/wallpaper-%2-%3.jpg").arg(cacheDir, s.screenName).arg(generation);
            // Старые версии этого монитора больше не нужны.
            const QStringList old = QDir(cacheDir).entryList({QStringLiteral("wallpaper-%1-*.jpg").arg(s.screenName)});
            for (const QString &f : old)
                QFile::remove(cacheDir + QLatin1Char('/') + f);
            if (img.save(file, "JPG", 92))
                result.insert(s.screenName, QUrl::fromLocalFile(file));
            else
                qWarning() << "Wallpaper: не удалось сохранить" << file;
        }
        return result;
    }));
}

void Wallpaper::startMonitor()
{
    // xfconf-query -m печатает строку на каждое изменение настроек рабочего стола.
    m_monitor = new QProcess(this);
    auto *debounce = new QTimer(this);
    debounce->setSingleShot(true);
    debounce->setInterval(400);
    connect(debounce, &QTimer::timeout, this, &Wallpaper::reload);
    connect(m_monitor, &QProcess::readyReadStandardOutput, this, [this, debounce] {
        const QByteArray out = m_monitor->readAllStandardOutput();
        if (out.contains("last-image") || out.contains("image-style"))
            debounce->start();
    });
    m_monitor->start(QStringLiteral("xfconf-query"), {QStringLiteral("-c"), QStringLiteral("xfce4-desktop"), QStringLiteral("-m")});
}
