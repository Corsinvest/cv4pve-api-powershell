// Old cmdlet pages (markdown/<Cmdlet>.html) -> generated reference page.
import type { APIRoute, GetStaticPaths } from 'astro';
import cmdlets from '../../data/cmdlets.json';
import { redirectPage } from '../../lib/redirect';

export const getStaticPaths = (() =>
  Object.entries(cmdlets).map(([cmdlet, to]) => ({ params: { cmdlet }, props: { to } }))) satisfies GetStaticPaths;

export const GET: APIRoute = ({ props }) => redirectPage(props.to as string);
