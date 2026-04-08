/*
 * Cloudflare Worker — iCalendar CORS Proxy
 *
 * Proxies .ics calendar feed requests and adds CORS headers so the
 * dashboard can fetch iCloud / Outlook calendars from the browser.
 *
 * Deploy (free Cloudflare Workers account):
 *   1. Go to https://dash.cloudflare.com → Workers & Pages → Create
 *   2. Name it (e.g. "cal-proxy") → Deploy
 *   3. Click "Edit code", paste this file, then "Deploy"
 *   4. Copy the *.workers.dev URL and set CORS_PROXY in dashboard.html:
 *        const CORS_PROXY = 'https://cal-proxy.YOUR_SUBDOMAIN.workers.dev/?url=';
 *
 * Usage:
 *   GET https://cal-proxy.xxx.workers.dev/?url=https://p123-caldav.icloud.com/published/2/...
 *
 * Security: Only proxies to known calendar hosts. Add more to ALLOWED_HOSTS if needed.
 */

const ALLOWED_HOSTS = [
  'caldav.icloud.com',          // iCloud (p##-caldav.icloud.com)
  'outlook.office365.com',      // Outlook / Microsoft 365
  'outlook.live.com',           // Outlook personal
  'calendar.google.com',        // Google Calendar
];

function isAllowedHost(hostname) {
  return ALLOWED_HOSTS.some(h => hostname === h || hostname.endsWith('.' + h) || hostname.endsWith(h));
}

export default {
  async fetch(request) {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
          'Access-Control-Max-Age': '86400',
        },
      });
    }

    const { searchParams } = new URL(request.url);
    const target = searchParams.get('url');

    if (!target) {
      return new Response('Missing ?url= parameter', { status: 400 });
    }

    let parsed;
    try {
      parsed = new URL(target);
    } catch {
      return new Response('Invalid URL', { status: 400 });
    }

    if (!isAllowedHost(parsed.hostname)) {
      return new Response(`Host not allowed: ${parsed.hostname}`, { status: 403 });
    }

    try {
      const resp = await fetch(target, {
        headers: { 'Accept': 'text/calendar, text/plain, */*' },
      });

      const headers = new Headers(resp.headers);
      headers.set('Access-Control-Allow-Origin', '*');
      headers.set('Cache-Control', 'public, max-age=300'); // cache 5 min

      return new Response(resp.body, {
        status: resp.status,
        headers,
      });
    } catch (e) {
      return new Response(`Fetch failed: ${e.message}`, { status: 502 });
    }
  },
};
