import { Button } from './ui/button';

type Props = {
  href?: string;
  label: string;
  kind?: 'primary' | 'secondary';
  mark?: 'windows';
  arrow?: 'up' | 'right';
  downloadDialog?: boolean;
};

export default function ActionLink({ href, label, kind = 'primary', mark, arrow, downloadDialog = false }: Props) {
  if (downloadDialog) return (
    <Button type="button" variant={kind === 'primary' ? 'default' : 'outline'} className={`button button-${kind}`} data-download-open="" aria-haspopup="dialog">
      {mark === 'windows' && <span className="windows-mark" aria-hidden="true"><i /><i /><i /><i /></span>}
      {label}
    </Button>
  );
  const target = downloadDialog ? '#download-options' : href;
  if (!target) return null;

  return (
    <Button asChild variant={kind === 'primary' ? 'default' : 'outline'} className={`button button-${kind}`}>
      <a
        href={target}
        data-download-open={downloadDialog ? '' : undefined}
        aria-haspopup={downloadDialog ? 'dialog' : undefined}
        data-astro-reload={!downloadDialog && target.startsWith('tapload:') ? '' : undefined}
      >
        {mark === 'windows' && <span className="windows-mark" aria-hidden="true"><i /><i /><i /><i /></span>}
        {label}
        {arrow && <span aria-hidden="true">{arrow === 'right' ? '→' : '↗'}</span>}
      </a>
    </Button>
  );
}
