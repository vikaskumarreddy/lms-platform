import { Routes } from '@angular/router';
import { AdminLayoutComponent } from './layout/admin-layout.component';
import { LoginComponent } from './pages/login/login.component';
import { RegisterComponent } from './pages/register/register.component';
import { DashboardComponent } from './pages/dashboard/dashboard.component';
import { StudentsComponent } from './pages/students/students.component';
import { StudentDetailComponent } from './pages/students/student-detail/student-detail.component';
import { CoursesComponent } from './pages/courses/courses.component';
import { CourseDetailComponent } from './pages/course-detail/course-detail.component';
import { FacultyComponent } from './pages/faculty/faculty.component';
import { PlacementsComponent } from './pages/placements/placements.component';
import { PaymentsComponent } from './pages/payments/payments.component';
import { SettingsComponent } from './pages/settings/settings.component';
import { ThemeSettingsComponent } from './pages/theme-settings/theme-settings.component';
import { CalendarEventsComponent } from './pages/calendar-events/calendar-events.component';
import { AssignmentsAdminComponent } from './pages/assignments-admin/assignments-admin.component';
import { ExamsAdminComponent } from './pages/exams-admin/exams-admin.component';
import { QaAdminComponent } from './pages/qa-admin/qa-admin.component';
import { NotificationsAdminComponent } from './pages/notifications-admin/notifications-admin.component';
import { SubscriptionsAdminComponent } from './pages/subscriptions-admin/subscriptions-admin.component';
import { EventsAdminComponent } from './pages/events-admin/events-admin.component';
import { BookmarksAdminComponent } from './pages/bookmarks-admin/bookmarks-admin.component';
import { BatchesComponent } from './pages/batches/batches.component';
import { BatchRulesComponent } from './pages/batches/batch-rules/batch-rules.component';
import { BatchCommunityComponent } from './pages/batch-community/batch-community.component';

import { GradingAdminComponent } from './pages/grading-admin/grading-admin.component';
import { AttendanceAdminComponent } from './pages/attendance-admin/attendance-admin.component';
import { CertificatesAdminComponent } from './pages/certificates-admin/certificates-admin.component';
import { AssessmentPaperComponent } from './pages/assessment-paper/assessment-paper.component';
import { CompanyQuestionsComponent } from './pages/company-questions/company-questions.component';
import { MediaHubComponent } from './pages/media-hub/media-hub.component';
import { PaymentSettingsComponent } from './pages/payment-settings/payment-settings.component';
import { OrganizationsComponent } from './pages/organizations/organizations.component';
import { OrgSubscriptionsComponent } from './pages/org-subscriptions/org-subscriptions.component';
import { AccountComponent } from './pages/account/account.component';
import { PlatformAddonsComponent } from './pages/platform-addons/platform-addons.component';
import { PlatformBillingComponent } from './pages/platform-billing/platform-billing.component';
import { LeaderboardAdminComponent } from './pages/leaderboard-admin/leaderboard-admin.component';
import { PublicVerifyComponent } from './pages/public-verify/public-verify.component';
import { adminGuard, adminOnlyGuard, orgAdminGuard } from './guards/admin.guard';

export const routes: Routes = [
  { path: 'login', component: LoginComponent },
  { path: 'register', component: RegisterComponent },
  { path: 'verify/:credentialId', component: PublicVerifyComponent },
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
      // Question-paper builder for an in-app assignment/exam; :type is "assignments" or "exams".
      { path: 'assessment-paper/:type/:id', component: AssessmentPaperComponent },
      { path: 'grading-admin', component: GradingAdminComponent },
      { path: 'attendance-admin', component: AttendanceAdminComponent },
      { path: 'certificates-admin', component: CertificatesAdminComponent },
      { path: 'qa-admin', component: QaAdminComponent },
      { path: 'company-questions', component: CompanyQuestionsComponent },
      { path: 'media-hub', component: MediaHubComponent },
      { path: 'leaderboard-admin', component: LeaderboardAdminComponent },
      { path: 'notifications-admin', component: NotificationsAdminComponent },
      { path: 'subscriptions-admin', component: SubscriptionsAdminComponent },
      { path: 'events-admin', component: EventsAdminComponent },
      { path: 'bookmarks-admin', component: BookmarksAdminComponent },
      { path: 'batches', component: BatchesComponent },
      { path: 'batches/rules', component: BatchRulesComponent },
      { path: 'batch-community', component: BatchCommunityComponent },
      { path: 'payments', component: PaymentsComponent },
      // The tenant's own Razorpay credentials — fees are collected into the
      // institute's account, so the keys are per-organization, not per-deployment.
      { path: 'payment-settings', component: PaymentSettingsComponent },
      { path: 'settings', component: SettingsComponent },
      // Per-organization brand colors. Guarded like Account: any org admin (platform
      // super admin or the tenant's own INSTITUTE_ADMIN) can restyle their portal.
      { path: 'theme-settings', component: ThemeSettingsComponent, canActivate: [orgAdminGuard] }
    ]
  },
  { path: '**', redirectTo: '/login' }
];
