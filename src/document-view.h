#ifndef DOCUMENT_VIEW_H
#define DOCUMENT_VIEW_H

#include <QQuickPaintedItem>
#include <QTimer>
#include "tile-cache.h"

class PopplerDocument;

class DocumentView : public QQuickPaintedItem {
  Q_OBJECT
  Q_PROPERTY(PopplerDocument *document READ document WRITE setDocument NOTIFY documentChanged);
  Q_PROPERTY(qreal contentX READ contentX WRITE setContentX NOTIFY contentXChanged);
  Q_PROPERTY(qreal contentY READ contentY WRITE setContentY NOTIFY contentYChanged);

public:
  DocumentView(QQuickItem *parent = 0);
  ~DocumentView();

  PopplerDocument *document() const;
  void setDocument(PopplerDocument *document);

  qreal contentX() const;
  void setContentX(qreal x);

  qreal contentY() const;
  void setContentY(qreal y);

  void paint(QPainter *painter);

protected:
  void geometryChanged(const QRectF& newGeometry, const QRectF& oldGeometry);

signals:
  void documentChanged();
  void contentXChanged();
  void contentYChanged();

private slots:
  void refreshTiles();
  void tileAdded();
  void init();

private:
  PopplerDocument *m_doc;
  TileCache *m_cache;
  qreal m_x;
  qreal m_y;
  QTimer m_timer;

  TileRequest *m_request;
};

#endif /* DOCUMENT_VIEW_H */
