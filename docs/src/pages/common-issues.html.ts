// Old MkDocs page common-issues.html.
import type { APIRoute } from 'astro';
import { redirectPage } from '../lib/redirect';

export const GET: APIRoute = () => redirectPage('troubleshooting/');
