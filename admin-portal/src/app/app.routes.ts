import { Routes } from '@angular/router';
import { AdminLayoutComponent } from './layout/admin-layout.component';
import { LoginComponent } from './pages/login/login.component';
import { DashboardComponent } from './pages/dashboard/dashboard.component';
import { StudentsComponent } from './pages/students/students.component';
import { StudentDetailComponent } from './pages/students/student-detail/student-detail.component';
import { CoursesComponent } from './pages/courses/courses.component';
import { CourseDetailComponent } from './pages/course-detail/course-detail.component';
import { FacultyComponent } from './pages/faculty/faculty.component';
import { PlacementsComponent } from './pages/placements/placements.component';
import { PaymentsComponent } from './pages/payments/payments.component';
import { SettingsComponent } from './pages/settings/settings.component';
import { CalendarEventsComponent } from './pages/calendar-events/calendar-events.component';
import { AssignmentsAdminComponent } from './pages/assignments-admin/assignments-admin.component';
import { ExamsAdminComponent } from './pages/exams-admin/exams-admin.component';
import { QaAdminComponent } from './pages/qa-admin/qa-admin.component';
import { NotificationsAdminComponent } from './pages/notifications-admin/notifications-admin.component';
import { SubscriptionsAdminComponent } from './pages/subscriptions-admin/subscriptions-admin.component';
import { EventsAdminComponent } from './pages/events-admin/events-admin.component';
import { BookmarksAdminComponent } from './pages/bookmarks-admin/bookmarks-admin.component';
import { BatchesComponent } from './pages/batches/batches.component';
import { GradingAdminComponent } from './pages/grading-admin/grading-admin.component';
import { AttendanceAdminComponent } from './pages/attendance-admin/attendance-admin.component';
import { CertificatesAdminComponent } from './pages/certificates-admin/certificates-admin.component';
import { OrganizationsComponent } from './pages/organizations/organizations.component';
import { OrgSubscriptionsComponent } from './pages/org-subscriptions/org-subscriptions.component';
import { AccountComponent } from './pages/account/account.component';
import { PlatformAddonsComponent } from './pages/platform-addons/platform-addons.component';
import { PlatformBillingComponent } from './pages/platform-billing/platform-billing.component';
import { adminGuard, adminOnlyGuard, orgAdminGuard } from './guards/admin.guard';

export const routes: Routes = [
  { path: 'login', component: LoginComponent },
  {
    path: '',
    component: AdminLayoutComponent,
    canActivate: [adminGuard],
    children: [
      { path: '', component: DashboardComponent },
      { path: 'organizations', component: OrganizationsComponent, canActivate: [adminOnlyGuard] },
      { path: 'org-subscriptions', component: OrgSubscriptionsComponent, canActivate: [adminOnlyGuard] },
      { path: 'platform-addons', component: PlatformAddonsComponent, canActivate: [adminOnlyGuard] },
      { path: 'platform-billing', component: PlatformBillingComponent, canActivate: [adminOnlyGuard] },
      // Account is the tenant's own billing surface. Guarded on ROLE, not hostname:
      // in dev every host resolves to the platform domain, so a hostname check would
      // hide this from the institute admins it exists for.
      { path: 'account', component: AccountComponent, canActivate: [orgAdminGuard] },
      { path: 'students', component: StudentsComponent },
      { path: 'students/:id', component: StudentDetailComponent },
      { path: 'courses', component: CoursesComponent },
      { path: 'courses/:id', component: CourseDetailComponent },
      { path: 'faculty', component: FacultyComponent },
      { path: 'placements', component: PlacementsComponent },
      { path: 'calendar-events', component: CalendarEventsComponent },
      { path: 'assignments-admin', component: AssignmentsAdminComponent },
      { path: 'exams-admin', component: ExamsAdminComponent },
      { path: 'grading-admin', component: GradingAdminComponent },
      { path: 'attendance-admin', component: AttendanceAdminComponent },
      { path: 'certificates-admin', component: CertificatesAdminComponent },
      { path: 'qa-admin', component: QaAdminComponent },
      { path: 'notifications-admin', component: NotificationsAdminComponent },
      { path: 'subscriptions-admin', component: SubscriptionsAdminComponent },
      { path: 'events-admin', component: EventsAdminComponent },
      { path: 'bookmarks-admin', component: BookmarksAdminComponent },
      { path: 'batches', component: BatchesComponent },
      { path: 'payments', component: PaymentsComponent },
      { path: 'settings', component: SettingsComponent }
    ]
  },
  { path: '**', redirectTo: '/login' }
];
