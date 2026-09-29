/*
 * Redirects for the URLs of the old MkDocs site (use_directory_urls: false, so pages ended in
 * .html). GitHub Pages has no server-side redirects: each old URL gets a small HTML page that
 * sends the browser, and search engines, to the new one.
 */
const BASE = import.meta.env.BASE_URL.replace(/\/$/, '');
const SITE = (import.meta.env.SITE ?? '').replace(/\/$/, '');

export function redirectPage(to: string): Response {
  const url = `${SITE}${BASE}/${to.replace(/^\//, '')}`;
  const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Moved</title>
<link rel="canonical" href="${url}">
<meta name="robots" content="noindex">
<meta http-equiv="refresh" content="0; url=${url}">
</head>
<body><p>This page has moved to <a href="${url}">${url}</a>.</p></body>
</html>
`;
  return new Response(html, { headers: { 'Content-Type': 'text/html; charset=utf-8' } });
}
