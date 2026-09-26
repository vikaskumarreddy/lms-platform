export interface MenuItem {
  id: string;
  label: string;
  route: string;
  exact?: boolean;
  /** If present, item is only shown when the current org's category is in this list. */
  categories?: string[];
  badge?: 'pendingApprovals' | 'account';
}

export interface MenuSection {
  groupLabel?: string;
  items: MenuItem[];
}

export const PLATFORM_SECTIONS: MenuSection[] = [
  {
    items: [
      { id: 'dashboard', label: '📊 Dashboard', route: '/', exact: true },
      { id: 'organizations', label: '🏢 Organizations', route: '/organizations' },
    ],
  },
  {
    groupLabel: 'Billing & Plans',
    items: [
      { id: 'org-subscriptions', label: '⭐ Platform Plans', route: '/org-subscriptions' },
      { id: 'platform-addons', label: '🧩 Add-ons', route: '/platform-addons' },
      { id: 'platform-billing', label: '🧾 Subscriptions', route: '/platform-billing', badge: 'pendingApprovals' },
    ],
  },
  {
    groupLabel: 'Platform',
    items: [
      { id: 'payments', label: '💳 Payments', route: '/payments' },
      { id: 'notifications-admin', label: '🔔 Notifications', route: '/notifications-admin' },
      { id: 'settings', label: '⚙️ Settings', route: '/settings' },
    ],
  },
];

export const INSTRUCTOR_SECTIONS: MenuSection[] = [
  {
    items: [
      { id: 'dashboard', label: '📊 Dashboard', route: '/', exact: true },
      { id: 'students', label: '🎓 Students', route: '/students' },
      { id: 'batch-community', label: '💬 Batch Community', route: '/batch-community' },
      { id: 'courses', label: '📚 Courses', route: '/courses' },
      { id: 'placements', label: '💼 Placements', route: '/placements' },
      { id: 'notifications-admin', label: '🔔 Notifications', route: '/notifications-admin' },
      { id: 'events-admin', label: '🎉 Events', route: '/events-admin' },
      { id: 'calendar-events', label: '📅 Calendar Events', route: '/calendar-events' },
      { id: 'assignments-admin', label: '📝 Assignments', route: '/assignments-admin' },
      { id: 'exams-admin', label: '📋 Exams', route: '/exams-admin' },
      { id: 'grading-admin', label: '✅ Grading', route: '/grading-admin' },
      { id: 'attendance-admin', label: '🗓️ Attendance', route: '/attendance-admin' },
      { id: 'certificates-admin', label: '🎓 Certificates', route: '/certificates-admin' },
      { id: 'qa-admin', label: '💬 Q&A', route: '/qa-admin' },
      { id: 'company-questions', label: '🏢 Company Questions', route: '/company-questions' },
      { id: 'coding-challenges', label: '💻 Coding Bank', route: '/coding-challenges' },
      { id: 'media-hub', label: '🎬 Media & Files', route: '/media-hub' },
      { id: 'leaderboard-admin', label: '🏆 Leaderboard', route: '/leaderboard-admin' },
      { id: 'social-handles', label: '📱 Social Handles', route: '/social-handles' },
      { id: 'settings', label: '⚙️ Settings', route: '/settings' },
    ],
  },
];

export const TENANT_SECTIONS: MenuSection[] = [
  {
    items: [
      { id: 'dashboard', label: '📊 Dashboard', route: '/', exact: true },
      { id: 'students', label: '🎓 Students', route: '/students' },
      { id: 'daily-attendance', label: '🗓️ Daily Attendance', route: '/attendance-admin', categories: ['SCHOOL'] },
      { id: 'batches', label: '👥 Batches', route: '/batches' },
      { id: 'batch-rules', label: '⚡ Batch Rules', route: '/batches/rules' },
      { id: 'batch-community', label: '💬 Batch Community', route: '/batch-community' },
      { id: 'courses', label: '📚 Courses', route: '/courses' },
      { id: 'faculty', label: '👨🏫 Faculty', route: '/faculty' },
      { id: 'placements', label: '💼 Placements', route: '/placements' },
      { id: 'subscriptions-admin', label: '⭐ Subscriptions', route: '/subscriptions-admin' },
      { id: 'notifications-admin', label: '🔔 Notifications', route: '/notifications-admin' },
      { id: 'events-admin', label: '🎉 Events', route: '/events-admin' },
      { id: 'bookmarks-admin', label: '🔖 Bookmarks', route: '/bookmarks-admin' },
      { id: 'calendar-events', label: '📅 Calendar Events', route: '/calendar-events' },
      { id: 'assignments-admin', label: '📝 Assignments', route: '/assignments-admin' },
      { id: 'exams-admin', label: '📋 Exams', route: '/exams-admin' },
      { id: 'grading-admin', label: '✅ Grading', route: '/grading-admin' },
      { id: 'attendance-admin', label: '🗓️ Attendance', route: '/attendance-admin' },
      { id: 'certificates-admin', label: '🎓 Certificates', route: '/certificates-admin' },
      { id: 'qa-admin', label: '💬 Q&A', route: '/qa-admin' },
      { id: 'company-questions', label: '🏢 Company Questions', route: '/company-questions' },
      { id: 'coding-challenges', label: '💻 Coding Bank', route: '/coding-challenges' },
      { id: 'media-hub', label: '🎬 Media & Files', route: '/media-hub' },
      { id: 'leaderboard-admin', label: '🏆 Leaderboard', route: '/leaderboard-admin' },
      { id: 'social-handles', label: '📱 Social Handles', route: '/social-handles' },
      { id: 'payments', label: '💳 Payments', route: '/payments' },
      { id: 'payment-settings', label: '⚙️ Payment Settings', route: '/payment-settings' },
      { id: 'account', label: '🧾 Account', route: '/account', badge: 'account' },
      { id: 'settings', label: '⚙️ Settings', route: '/settings' },
      { id: 'theme-settings', label: '🎨 Theme', route: '/theme-settings' },
    ],
  },
];
