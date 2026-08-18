FROM node:20-alpine AS build
WORKDIR /app
COPY package.json .
RUN npm install
COPY . .
RUN npm run build -- --configuration production

FROM nginx:alpine
COPY --from=build /app/dist/admin-portal /usr/share/nginx/html
# Custom nginx config: serves the SPA AND proxies /api to the backend (backend:8080 on
# the compose network), so the app works when accessed at :4200 (placements.com:4200).
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]