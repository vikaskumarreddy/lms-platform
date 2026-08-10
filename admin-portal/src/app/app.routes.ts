import { Routes } from '@angular/router';
import { AdminLayoutComponent } from './layout/admin-layout.component';
import { LoginComponent } from './pages/login/login.component';
import { DashboardComponent } from './pages/dashboard/dashboard.component';
import { StudentsComponent } from './pages/students/students.component';
import { CoursesComponent } from './pages/courses/courses.component';
import { FacultyComponent } from './pages/faculty/faculty.component';
import { PlacementsComponent } from './pages/placements/placements.component';
import { PaymentsComponent } from './pages/payments/payments.component';
import { SettingsComponent } from './pages/settings/settings.component';
import { CalendarEventsComponent } from './pages/calendar-events/calendar-events.component';
import { AssignmentsAdminComponent } from './pages/assignments-admin/assignments-admin.component';
import { ExamsAdminComponent } from './pages/exams-admin/exams-admin.component';
import { AchievementsAdminComponent } from './pages/achievements-admin/achievements-admin.component';
import { QaAdminComponent } from './pages/qa-admin/qa-admin.component';
import { NotificationsAdminComponent } from './pages/notifications-admin/notifications-admin.component';
import { SubscriptionsAdminComponent } from './pages/subscriptions-admin/subscriptions-admin.component';
import { EventsAdminComponent } from './pages/events-admin/events-admin.component';
import { BookmarksAdminComponent } from './pages/bookmarks-admin/bookmarks-admin.component';
import { HomeContentComponent } from './pages/home-content/home-content.component';
import { BatchesComponent } from './pages/batches/batches.component';
import { adminGuard } from './guards/admin.guard';

export const routes: Routes = [
  { path: 'login', component: LoginComponent },
  {
    path: '',
    component: AdminLayoutComponent,
    canActivate: [adminGuard],
    children: [
      { path: '', component: DashboardComponent },
      { path: 'students', component: StudentsComponent },
      { path: 'courses', component: CoursesComponent },
      { path: 'faculty', component: FacultyComponent },
      { path: 'placements', component: PlacementsComponent },
      { path: 'calendar-events', component: CalendarEventsComponent },
      { path: 'assignments-admin', component: AssignmentsAdminComponent },
      { path: 'exams-admin', component: ExamsAdminComponent },
      { path: 'achievements-admin', component: AchievementsAdminComponent },
      { path: 'qa-admin', component: QaAdminComponent },
      { path: 'notifications-admin', component: NotificationsAdminComponent },
      { path: 'subscriptions-admin', component: SubscriptionsAdminComponent },
      { path: 'events-admin', component: EventsAdminComponent },
      { path: 'bookmarks-admin', component: BookmarksAdminComponent },
      { path: 'home-content', component: HomeContentComponent },
      { path: 'batches', component: BatchesComponent },
      { path: 'payments', component: PaymentsComponent },
      { path: 'settings', component: SettingsComponent }
    ]
  },
  { path: '**', redirectTo: '/login' }
];
