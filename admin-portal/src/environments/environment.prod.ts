// Production environment — served at axisoraforge.in and *.axisoraforge.in
// The Angular app is served by the same Nginx that proxies /api/* to Spring Boot,
// so apiUrl uses a relative path (no origin needed).
export const environment = {
  production: true,
  // Relative URL — works on ALL subdomains automatically:
  // axisoraforge.in/api/..., axisora.axisoraforge.in/api/..., manyasree.axisoraforge.in/api/...
  apiUrl: '/api',
  // Root domain (used for building tenant URLs in the UI where needed)
  rootDomain: 'axisoraforge.in',
};
