import { Card } from './ui/card';
import { Badge } from './ui/badge';

type Props = {
  id: string;
  kind: string;
  name: string;
  description: string;
  kindLabel: string;
  searchText: string;
  iconPath: string;
  detailHref: string;
  detailsLabel: string;
  appHref: string;
  openLabel: string;
  includedLabel: string;
};

export default function CatalogCard({
  id, kind, name, description, kindLabel, searchText, iconPath,
  detailHref, detailsLabel, appHref, openLabel, includedLabel,
}: Props) {
  return (
    <Card
      role="article"
      id={id}
      className={`plugin-card kind-card-${kind}`}
      data-plugin-card=""
      data-kind={kind}
      data-search={searchText}
      data-sort-name={name}
    >
      <div className="plugin-topline">
        <span className="plugin-icon" aria-hidden="true">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.45" strokeLinecap="round" strokeLinejoin="round">
            <path d={iconPath} />
          </svg>
        </span>
        <Badge variant="outline" className={`kind-pill kind-${kind}`}>
          <span className="kind-marker" aria-hidden="true" />{kindLabel}
        </Badge>
      </div>
      <h2>{name}</h2>
      <p className="plugin-description">{description}</p>
      <div className="plugin-action">
        <a className="plugin-detail-link" href={detailHref}>{detailsLabel}<span aria-hidden="true">↗</span></a>
        {kind === 'core' ? (
          <span className="included"><span aria-hidden="true">✓</span>{includedLabel}</span>
        ) : (
          <a className="plugin-link" href={appHref} data-astro-reload="">{openLabel}<span aria-hidden="true">↗</span></a>
        )}
      </div>
    </Card>
  );
}
