# Axisora Forge Academy LMS - API Reference

## Authentication
- POST /api/auth/register - Register new user
- POST /api/auth/login - Login user

## Courses
- GET /api/courses - Get all courses
- GET /api/courses/{id} - Get course by ID
- POST /api/courses - Create course (Admin)
- PUT /api/courses/{id} - Update course (Admin)
- DELETE /api/courses/{id} - Delete course (Admin)

## Dashboard
- GET /api/dashboard/stats - Get dashboard statistics

## Placements
- GET /api/placements - Get all placement drives
- GET /api/placements/{id} - Get placement drive by ID
- POST /api/placements - Create placement drive (Admin)

## Swagger UI
Full API documentation available at: http://localhost:8080/swagger-ui.html
