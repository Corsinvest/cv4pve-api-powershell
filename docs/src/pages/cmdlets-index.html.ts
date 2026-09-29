// Old MkDocs page cmdlets-index.html.
import type { APIRoute } from 'astro';
import { redirectPage } from '../lib/redirect';

export const GET: APIRoute = () => redirectPage('reference/');
