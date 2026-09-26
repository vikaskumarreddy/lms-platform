import { Component, OnInit, ElementRef, ViewChild } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

export type TemplateCategory = 'promotional' | 'course' | 'placement' | 'general';
export type AspectRatio = '9:16' | '1:1' | 'whatsapp';

export interface TemplateField {
  key: string;
  label: string;
  type: 'text' | 'number' | 'date' | 'select';
  placeholder?: string;
  defaultValue?: string;
  options?: string[];
}

export interface SocialTemplate {
  id: string;
  name: string;
  category: TemplateCategory;
  emoji: string;
  description: string;
  supportedRatios: AspectRatio[];
  primaryColor: string;
  fields: TemplateField[];
  captionTemplate: string;
}

interface CanvasState {
  templateId: string;
  aspectRatio: AspectRatio;
  fieldValues: Record<string, string>;
  showLogo: boolean;
  orgName: string;
}

export interface CanvasElement {
  id: string;
  type: 'image' | 'text' | 'badge';
  name: string;
  x: number;
  y: number;
  width: number;
  height: number;
  zIndex: number;
  isLocked?: boolean;

  // Image properties
  src?: string;
  objectFit?: 'contain' | 'cover';
  borderRadius?: number; // px (0 to 100)
  opacity?: number;      // 0.1 to 1.0
  hasShadow?: boolean;
  flipH?: boolean;

  // Text properties
  text?: string;
  fontSize?: number;
  fontFamily?: string;
  fontWeight?: string;
  color?: string;
  textAlign?: 'left' | 'center' | 'right';
  bgColor?: string;
  borderColor?: string;
  paddingX?: number;
  paddingY?: number;
}

export const PRESET_AVATARS = [
  {
    id: 'woman-mentor',
    name: 'Tech Mentor (Female)',
    icon: '👩‍🏫',
    svg: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 240" fill="none"><path d="M40 180 C40 145 70 140 100 140 C130 140 160 145 160 180 L175 240 L25 240 Z" fill="#2952E3"/><path d="M75 142 L100 185 L125 142 Z" fill="#E8B084"/><path d="M70 142 L100 190 L130 142" stroke="#1E3EA8" stroke-width="4" fill="none"/><rect x="88" y="115" width="24" height="30" rx="6" fill="#E8B084"/><ellipse cx="100" cy="90" rx="38" ry="44" fill="#E8B084"/><path d="M60 85 C55 50 75 30 100 30 C125 30 145 50 140 85 C145 105 140 130 136 135 C132 125 132 95 130 90 C125 70 115 65 100 65 C85 65 75 70 70 90 C68 95 68 125 64 135 C60 130 55 105 60 85 Z" fill="#1C1B24"/><ellipse cx="86" cy="88" rx="4" ry="4" fill="#1C1B24"/><ellipse cx="114" cy="88" rx="4" ry="4" fill="#1C1B24"/><path d="M80 80 Q86 76 92 80" stroke="#1C1B24" stroke-width="2.5" stroke-linecap="round" fill="none"/><path d="M108 80 Q114 76 120 80" stroke="#1C1B24" stroke-width="2.5" stroke-linecap="round" fill="none"/><path d="M88 104 Q100 115 112 104" stroke="#873E23" stroke-width="3" stroke-linecap="round" fill="none"/></svg>`
  },
  {
    id: 'man-speaker',
    name: 'Tech Expert (Male)',
    icon: '👨‍💼',
    svg: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 240" fill="none"><path d="M35 180 C35 148 68 142 100 142 C132 142 165 148 165 180 L180 240 L20 240 Z" fill="#1E293B"/><path d="M78 143 L100 188 L122 143 Z" fill="#0EA5E9"/><rect x="88" y="115" width="24" height="30" rx="4" fill="#F2C5A5"/><ellipse cx="100" cy="90" rx="36" ry="42" fill="#F2C5A5"/><path d="M64 80 C62 48 76 32 100 32 C124 32 138 48 136 80 C136 60 128 50 100 50 C72 50 64 60 64 80 Z" fill="#2D2013"/><rect x="74" y="80" width="22" height="16" rx="4" stroke="#0EA5E9" stroke-width="3" fill="none"/><rect x="104" y="80" width="22" height="16" rx="4" stroke="#0EA5E9" stroke-width="3" fill="none"/><line x1="96" y1="88" x2="104" y2="88" stroke="#0EA5E9" stroke-width="3"/><circle cx="85" cy="88" r="3" fill="#2D2013"/><circle cx="115" cy="88" r="3" fill="#2D2013"/><path d="M88 106 Q100 116 112 106" stroke="#A04020" stroke-width="3" stroke-linecap="round" fill="none"/></svg>`
  },
  {
    id: 'trophy',
    name: 'Golden Trophy',
    icon: '🏆',
    svg: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" fill="none"><rect x="70" y="160" width="60" height="14" rx="4" fill="#B45309"/><rect x="80" y="145" width="40" height="18" rx="2" fill="#D97706"/><path d="M92 120 L92 145 L108 145 L108 120 Z" fill="#F59E0B"/><path d="M55 45 C55 110 82 120 100 120 C118 120 145 110 145 45 Z" fill="#F59E0B"/><path d="M55 55 C35 55 35 90 60 95" stroke="#F59E0B" stroke-width="8" stroke-linecap="round" fill="none"/><path d="M145 55 C165 55 165 90 140 95" stroke="#F59E0B" stroke-width="8" stroke-linecap="round" fill="none"/><path d="M100 65 L104 77 L117 77 L107 85 L110 97 L100 90 L90 97 L93 85 L83 77 L96 77 Z" fill="#FEF3C7"/></svg>`
  },
  {
    id: 'grad-cap',
    name: 'Graduation Cap',
    icon: '🎓',
    svg: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" fill="none"><path d="M100 40 L180 75 L100 110 L20 75 Z" fill="#1E293B"/><path d="M100 40 L180 75 L100 78 L20 75 Z" fill="#334155"/><path d="M55 92 L55 130 C55 155 145 155 145 130 L145 92" fill="#0F172A"/><line x1="100" y1="75" x2="165" y2="95" stroke="#F59E0B" stroke-width="3"/><circle cx="100" cy="75" r="5" fill="#F59E0B"/><rect x="160" y="95" width="10" height="24" rx="3" fill="#F59E0B"/></svg>`
  }
];

export const SOCIAL_TEMPLATES: SocialTemplate[] = [
  {
    id: 'course-launch',
    name: 'Course Batch Launch',
    category: 'course',
    emoji: '🎓',
    description: 'Professional batch announcement poster',
    supportedRatios: ['9:16', '1:1'],
    primaryColor: '#1a237e',
    fields: [
      { key: 'courseName',    label: 'Course Name',        type: 'text',   placeholder: 'Spring Boot',               defaultValue: 'Spring Boot' },
      { key: 'courseSubtitle',label: 'Batch Subtitle',     type: 'text',   placeholder: 'Mastery Batch',             defaultValue: 'Mastery Batch' },
      { key: 'batchType',     label: 'Batch Type',         type: 'text',   placeholder: 'Live + Recorded Batch',     defaultValue: 'Live + Recorded Batch' },
      { key: 'cohort',        label: 'Cohort',             type: 'text',   placeholder: 'Oct 2026',                  defaultValue: 'Oct 2026' },
      { key: 'earlyBirdDate', label: 'Early Bird Date',    type: 'date',   defaultValue: '' },
      { key: 'regularDate',   label: 'Regular Class Date', type: 'date',   defaultValue: '' },
      { key: 'timing',        label: 'Timing',             type: 'text',   placeholder: '07:00 PM - 09:00 PM',       defaultValue: '07:00 PM - 09:00 PM' },
      { key: 'mode',          label: 'Mode',               type: 'text',   placeholder: 'Offline | Live | Recorded', defaultValue: 'Offline | Live Online | Recorded' },
      { key: 'contact',       label: 'Phone',              type: 'text',   placeholder: '+91 90000 00000',           defaultValue: '' },
      { key: 'website',       label: 'Website',            type: 'text',   placeholder: 'www.youracademy.com',       defaultValue: '' },
      { key: 'orgTagline',    label: 'Org Tagline',        type: 'text',   placeholder: 'EXCELLENCE IN TRAINING',    defaultValue: 'EXCELLENCE IN TRAINING' },
    ],
    captionTemplate: '🚀 *New Batch — {{courseName}} {{courseSubtitle}}!*\n\n📅 Early Bird: {{earlyBirdDate}}\n📅 Regular: {{regularDate}}\n⏰ Timing: {{timing}}\n💻 Mode: {{mode}}\n\nEnroll now!\n📞 {{contact}}\n🌐 {{website}}\n\n#NewBatch #{{courseName}}',
  },
  {
    id: 'promo-discount',
    name: 'Discount Offer',
    category: 'promotional',
    emoji: '🔥',
    description: 'Flash sale limited-time discount poster',
    supportedRatios: ['9:16', '1:1', 'whatsapp'],
    primaryColor: '#7B0000',
    fields: [
      { key: 'discountPercent', label: 'Discount %',       type: 'number', placeholder: '50',            defaultValue: '50' },
      { key: 'courseName',      label: 'Course Name',      type: 'text',   placeholder: 'Full-Stack Dev', defaultValue: 'Full-Stack Development' },
      { key: 'offerCode',       label: 'Offer Code',       type: 'text',   placeholder: 'SAVE50',         defaultValue: 'SAVE50' },
      { key: 'originalFee',     label: 'Original Fee',     type: 'text',   placeholder: '₹15,000',        defaultValue: '' },
      { key: 'discountedFee',   label: 'Discounted Fee',   type: 'text',   placeholder: '₹7,500',         defaultValue: '' },
      { key: 'expiryDate',      label: 'Offer Expires',    type: 'date',   defaultValue: '' },
      { key: 'contact',         label: 'Phone / Enroll',   type: 'text',   placeholder: '+91 90000 00000', defaultValue: '' },
    ],
    captionTemplate: '🔥 *LIMITED TIME OFFER!*\n\n{{discountPercent}}% OFF on {{courseName}}!\n\nUse code: *{{offerCode}}*\nOffer Price: {{discountedFee}}\n⏳ Expires: {{expiryDate}}\n\n📞 {{contact}}\n\n#Discount #{{courseName}}',
  },
  {
    id: 'promo-demo',
    name: 'Free Demo Class',
    category: 'promotional',
    emoji: '🎯',
    description: 'Invite leads to a free demo session',
    supportedRatios: ['9:16', '1:1', 'whatsapp'],
    primaryColor: '#4527A0',
    fields: [
      { key: 'courseName',  label: 'Course Name',      type: 'text', placeholder: 'Python Programming', defaultValue: 'Python Programming' },
      { key: 'demoDate',    label: 'Demo Date',         type: 'date', defaultValue: '' },
      { key: 'demoTime',    label: 'Demo Time',         type: 'text', placeholder: '06:00 PM',           defaultValue: '06:00 PM' },
      { key: 'platform',    label: 'Platform / Venue',  type: 'text', placeholder: 'Zoom / Offline',      defaultValue: 'Zoom' },
      { key: 'contact',     label: 'Register / Contact', type: 'text', placeholder: '+91 90000 00000',   defaultValue: '' },
      { key: 'keyTopics',   label: 'Key Topics',        type: 'text', placeholder: 'Basics, OOP, Projects', defaultValue: 'Basics, OOP, Projects' },
    ],
    captionTemplate: '🎯 *FREE DEMO CLASS — {{courseName}}*\n\n📅 {{demoDate}}\n⏰ {{demoTime}}\n📍 {{platform}}\n\nTopics: {{keyTopics}}\n\nRegister: {{contact}}\n\n#FreeDemoClass #{{courseName}}',
  },
  {
    id: 'placement-success',
    name: 'Student Placed!',
    category: 'placement',
    emoji: '🏆',
    description: 'Celebrate a student placement achievement',
    supportedRatios: ['1:1', '9:16'],
    primaryColor: '#1a1a2e',
    fields: [
      { key: 'studentName', label: 'Student Name',  type: 'text', placeholder: 'Ravi Kumar',        defaultValue: 'Ravi Kumar' },
      { key: 'companyName', label: 'Company',        type: 'text', placeholder: 'TCS',               defaultValue: 'TCS' },
      { key: 'role',        label: 'Job Role',       type: 'text', placeholder: 'Software Engineer', defaultValue: 'Software Engineer' },
      { key: 'ctc',         label: 'Package (LPA)',  type: 'text', placeholder: '8 LPA',             defaultValue: '8 LPA' },
      { key: 'courseName',  label: 'Course',         type: 'text', placeholder: 'Java Full Stack',   defaultValue: 'Java Full Stack' },
      { key: 'batchName',   label: 'Batch',          type: 'text', placeholder: 'Batch 5',           defaultValue: 'Batch 5' },
    ],
    captionTemplate: '🏆 *PLACED!*\n\n🌟 {{studentName}} placed at *{{companyName}}*\n\n📌 Role: {{role}}\n💰 Package: {{ctc}}\n📚 Course: {{courseName}}\n\nProud of you! 🎉\n\n#Placed #{{companyName}} #SuccessStory',
  },
  {
    id: 'placement-stats',
    name: 'Placement Stats',
    category: 'placement',
    emoji: '📊',
    description: 'Showcase overall placement statistics',
    supportedRatios: ['1:1', '9:16', 'whatsapp'],
    primaryColor: '#0d0221',
    fields: [
      { key: 'year',           label: 'Year / Batch',        type: 'text',   placeholder: '2024',  defaultValue: '2024' },
      { key: 'totalPlaced',    label: 'Students Placed',     type: 'number', placeholder: '120',   defaultValue: '120' },
      { key: 'avgPackage',     label: 'Avg Package (LPA)',   type: 'text',   placeholder: '6.5',   defaultValue: '6.5' },
      { key: 'topPackage',     label: 'Top Package (LPA)',   type: 'text',   placeholder: '18',    defaultValue: '18' },
      { key: 'companiesCount', label: 'Companies',           type: 'number', placeholder: '45',    defaultValue: '45' },
      { key: 'placementRate',  label: 'Placement Rate %',    type: 'text',   placeholder: '92',    defaultValue: '92' },
    ],
    captionTemplate: '📊 *{{year}} PLACEMENT HIGHLIGHTS!*\n\n✅ {{totalPlaced}} Students Placed\n🏢 {{companiesCount}}+ Companies\n💰 Avg: {{avgPackage}} LPA\n🏆 Top: {{topPackage}} LPA\n📈 Rate: {{placementRate}}%\n\n#PlacementResults #{{year}}',
  },
  {
    id: 'course-completion',
    name: 'Batch Completed',
    category: 'course',
    emoji: '🎊',
    description: 'Celebrate a batch course completion',
    supportedRatios: ['1:1', '9:16'],
    primaryColor: '#064E3B',
    fields: [
      { key: 'courseName',     label: 'Course Name',         type: 'text',   placeholder: 'Digital Marketing', defaultValue: 'Digital Marketing' },
      { key: 'batchName',      label: 'Batch Name',          type: 'text',   placeholder: 'Batch 5',           defaultValue: 'Batch 5' },
      { key: 'studentCount',   label: 'Students Completed',  type: 'number', placeholder: '42',                defaultValue: '42' },
      { key: 'duration',       label: 'Duration',            type: 'text',   placeholder: '6 Months',          defaultValue: '6 Months' },
      { key: 'completionDate', label: 'Completion Date',     type: 'date',   defaultValue: '' },
    ],
    captionTemplate: '🎓 *BATCH COMPLETED!*\n\n{{studentCount}} students from {{batchName}} completed *{{courseName}}*!\n\nDuration: {{duration}}\nCompleted on: {{completionDate}}\n\nCongratulations! 🎉\n\n#CourseCompleted #{{courseName}}',
  },
  {
    id: 'general-holiday',
    name: 'Holiday Notice',
    category: 'general',
    emoji: '🎉',
    description: 'Festive holiday announcement poster',
    supportedRatios: ['1:1', '9:16', 'whatsapp'],
    primaryColor: '#4A0072',
    fields: [
      { key: 'holidayName',  label: 'Holiday Name',    type: 'text', placeholder: 'Diwali',                            defaultValue: 'Diwali' },
      { key: 'holidayEmoji', label: 'Holiday Emoji',   type: 'text', placeholder: '🪔',                       defaultValue: '🪔' },
      { key: 'holidayDate',  label: 'Closed On',       type: 'date', defaultValue: '' },
      { key: 'resumeDate',   label: 'Classes Resume',  type: 'date', defaultValue: '' },
      { key: 'wishMessage',  label: 'Wish Message',    type: 'text', placeholder: 'May this festival bring joy & prosperity!', defaultValue: 'May this festival bring joy & prosperity to you and your family!' },
    ],
    captionTemplate: '🎉 *HAPPY {{holidayName}}!*\n\n{{holidayEmoji}} {{wishMessage}}\n\nInstitute closed on {{holidayDate}}.\nClasses resume from {{resumeDate}}.\n\n#Happy{{holidayName}} #HolidayNotice',
  },
  {
    id: 'general-event',
    name: 'Event Invitation',
    category: 'general',
    emoji: '📢',
    description: 'Professional event or seminar invitation',
    supportedRatios: ['9:16', '1:1', 'whatsapp'],
    primaryColor: '#00695C',
    fields: [
      { key: 'eventName',     label: 'Event Name',           type: 'text',   placeholder: 'Industry Expert Seminar', defaultValue: 'Industry Expert Seminar' },
      { key: 'eventType',     label: 'Event Type',           type: 'select', options: ['Seminar', 'Workshop', 'Webinar', 'Masterclass', 'Hackathon'], defaultValue: 'Seminar' },
      { key: 'speaker',       label: 'Speaker / Guest',      type: 'text',   placeholder: 'Mr. Ramesh Rao',          defaultValue: '' },
      { key: 'speakerDesig',  label: 'Speaker Designation',  type: 'text',   placeholder: 'Senior Engineer @ Google', defaultValue: '' },
      { key: 'eventDate',     label: 'Date',                 type: 'date',   defaultValue: '' },
      { key: 'eventTime',     label: 'Time',                 type: 'text',   placeholder: '10:00 AM - 12:00 PM',     defaultValue: '10:00 AM' },
      { key: 'venue',         label: 'Venue / Platform',     type: 'text',   placeholder: 'Google Meet / Hall A',    defaultValue: '' },
      { key: 'contact',       label: 'Contact / Register',   type: 'text',   placeholder: '+91 90000 00000',         defaultValue: '' },
    ],
    captionTemplate: '📢 *YOU ARE INVITED!*\n\n🎤 {{eventType}}: {{eventName}}\n\n👤 {{speaker}}\n💼 {{speakerDesig}}\n📅 {{eventDate}}\n⏰ {{eventTime}}\n📍 {{venue}}\n\nRegister: {{contact}}\n\n#{{eventType}} #LearnGrow',
  },
];

@Component({
  selector: 'app-social-handles',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './social-handles.component.html',
  styleUrls: ['./social-handles.component.css']
})
export class SocialHandlesComponent implements OnInit {
  @ViewChild('cvs') cvsEl!: ElementRef<HTMLDivElement>;

  cats = [
    { id: 'promotional' as TemplateCategory, icon: '🔥', label: 'Promotional' },
    { id: 'course'       as TemplateCategory, icon: '📚', label: 'Courses' },
    { id: 'placement'    as TemplateCategory, icon: '🏆', label: 'Placements' },
    { id: 'general'      as TemplateCategory, icon: '📢', label: 'General' },
  ];

  allRatios = [
    { id: '9:16'     as AspectRatio, icon: '📱', label: 'Portrait (9:16)' },
    { id: '1:1'      as AspectRatio, icon: '⬛', label: 'Square (1:1)' },
    { id: 'whatsapp' as AspectRatio, icon: '💬', label: 'WhatsApp' },
  ];

  activeCategory: TemplateCategory = 'course';
  filtered: SocialTemplate[] = [];
  sel: SocialTemplate | null = null;
  availRatios: { id: AspectRatio; icon: string; label: string }[] = [];

  canvas: CanvasState = {
    templateId: '', aspectRatio: '9:16', fieldValues: {},
    showLogo: true, orgName: 'Your Academy',
  };

  // Canvas elements (custom images, avatars, badges, text)
  elements: CanvasElement[] = [];
  selectedElementId: string | null = null;
  presetAvatars = PRESET_AVATARS;
  activeSidebarTab: 'details' | 'layers' | 'presets' = 'details';

  // Interaction dragging & resizing state
  private isInteracting = false;
  private interactionType: 'drag' | 'resize' = 'drag';
  private resizeHandle: string = '';
  private startPointerX = 0;
  private startPointerY = 0;
  private initialElX = 0;
  private initialElY = 0;
  private initialElW = 0;
  private initialElH = 0;
  private boundPointerMove = this.onGlobalPointerMove.bind(this);
  private boundPointerUp = this.onGlobalPointerUp.bind(this);

  caption = '';
  copied = false;
  exporting = false;
  exportMsg = '';
  showIg = false;
  htmlToImageReady = false;

  get selectedElement(): CanvasElement | null {
    return this.elements.find(e => e.id === this.selectedElementId) || null;
  }

  ngOnInit() {
    this.filterTpls();
    this.checkLib();
  }

  private async checkLib() {
    try { await import('html-to-image' as any); this.htmlToImageReady = true; } catch { this.htmlToImageReady = false; }
  }

  selectCat(id: TemplateCategory) {
    this.activeCategory = id;
    this.filterTpls();
    this.sel = null;
    this.caption = '';
  }

  filterTpls() {
    this.filtered = SOCIAL_TEMPLATES.filter(t => t.category === this.activeCategory);
  }

  selectTpl(t: SocialTemplate) {
    this.sel = t;
    this.canvas.templateId = t.id;
    this.canvas.fieldValues = {};
    t.fields.forEach(f => this.canvas.fieldValues[f.key] = f.defaultValue || '');
    this.availRatios = this.allRatios.filter(r => t.supportedRatios.includes(r.id));
    this.canvas.aspectRatio = t.supportedRatios[0];
    this.genCaption();
  }

  fv(key: string): string {
    return this.canvas.fieldValues[key] || '';
  }

  formatDate(s: string): string {
    if (!s) return '';
    const d = new Date(s + 'T00:00:00');
    if (isNaN(d.getTime())) return s;
    const day = d.getDate();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const sfx = (day===1||day===21||day===31)?'st':(day===2||day===22)?'nd':(day===3||day===23)?'rd':'th';
    return day + sfx + ' ' + months[d.getMonth()] + ', ' + d.getFullYear();
  }

  genCaption() {
    if (!this.sel) return;
    let cap = this.sel.captionTemplate;
    Object.entries(this.canvas.fieldValues).forEach(([k, v]) => {
      cap = cap.replace(new RegExp('\\{\\{' + k + '\\}\\}', 'g'), v || '[' + k + ']');
    });
    cap = cap.replace(/\{\{[a-zA-Z]+\}\}/g, '');
    this.caption = cap;
  }

  copyCaption() {
    navigator.clipboard.writeText(this.caption).then(() => {
      this.copied = true; setTimeout(() => this.copied = false, 2500);
    });
  }

  shareWa() {
    window.open('https://wa.me/?text=' + encodeURIComponent(this.caption), '_blank');
  }

  // ════════════════════════════════════════════════════════
  // Canvas Dimensions & Hero Image Check
  // ════════════════════════════════════════════════════════
  getCanvasDims(): { width: number; height: number } {
    if (this.canvas.aspectRatio === '9:16') return { width: 300, height: 530 };
    if (this.canvas.aspectRatio === '1:1') return { width: 360, height: 360 };
    return { width: 360, height: 190 }; // whatsapp
  }

  hasHeroImage(): boolean {
    return this.elements.some(e => e.type === 'image');
  }

  // ════════════════════════════════════════════════════════
  // Image Upload & Presets
  // ════════════════════════════════════════════════════════
  triggerFileInput(fileInput: HTMLInputElement) {
    fileInput.click();
  }

  handleImageUpload(event: Event) {
    const input = event.target as HTMLInputElement;
    if (!input.files || input.files.length === 0) return;
    const file = input.files[0];
    const reader = new FileReader();
    reader.onload = (e: any) => {
      const base64 = e.target.result;
      this.addImageElement(base64, file.name || 'Photo');
      input.value = '';
    };
    reader.readAsDataURL(file);
  }

  applyPresetAvatar(preset: typeof PRESET_AVATARS[0]) {
    const svgDataUrl = 'data:image/svg+xml;utf8,' + encodeURIComponent(preset.svg);
    this.addImageElement(svgDataUrl, preset.name);
  }

  addImageElement(src: string, name = 'Image') {
    const dims = this.getCanvasDims();
    let initialW = 165;
    let initialH = 250;
    let initialX = dims.width - initialW;
    let initialY = dims.height - initialH - 35;

    if (this.canvas.aspectRatio === '1:1') {
      initialW = 160;
      initialH = 210;
      initialX = dims.width - initialW;
      initialY = dims.height - initialH - 30;
    } else if (this.canvas.aspectRatio === 'whatsapp') {
      initialW = 115;
      initialH = 145;
      initialX = dims.width - initialW;
      initialY = dims.height - initialH - 20;
    }

    const newEl: CanvasElement = {
      id: 'img-' + Date.now(),
      type: 'image',
      name: name,
      x: initialX,
      y: Math.max(0, initialY),
      width: initialW,
      height: initialH,
      zIndex: 1, // Behind text overlays, above template bg
      src: src,
      objectFit: 'contain',
      borderRadius: 0,
      opacity: 1,
      hasShadow: false,
      flipH: false,
    };

    this.elements.push(newEl);
    this.selectedElementId = newEl.id;
    this.activeSidebarTab = 'layers';
  }

  addText(isBadge = false) {
    const dims = this.getCanvasDims();
    const id = (isBadge ? 'badge-' : 'txt-') + Date.now();

    if (isBadge) {
      const newEl: CanvasElement = {
        id: id,
        type: 'badge',
        name: 'Discount Pill',
        x: Math.round(dims.width * 0.08),
        y: Math.round(dims.height * 0.65),
        width: 175,
        height: 38,
        zIndex: 5,
        text: 'Early Bird Discount available for Registrations till 30th Sep',
        fontSize: 10,
        fontWeight: '700',
        fontFamily: 'Poppins',
        color: '#0d1b5c',
        textAlign: 'center',
        bgColor: 'rgba(255,255,255,0.92)',
        borderColor: '#4FC3F7',
        borderRadius: 8,
        paddingX: 8,
        paddingY: 6,
      };
      this.elements.push(newEl);
      this.selectedElementId = newEl.id;
    } else {
      const newEl: CanvasElement = {
        id: id,
        type: 'text',
        name: 'Custom Heading',
        x: Math.round(dims.width * 0.1),
        y: Math.round(dims.height * 0.45),
        width: 180,
        height: 34,
        zIndex: 5,
        text: 'Special Announcement',
        fontSize: 14,
        fontWeight: '800',
        fontFamily: 'Montserrat',
        color: '#FFD700',
        textAlign: 'left',
        paddingX: 4,
        paddingY: 2,
      };
      this.elements.push(newEl);
      this.selectedElementId = newEl.id;
    }
    this.activeSidebarTab = 'layers';
  }

  // ════════════════════════════════════════════════════════
  // Drag & Resize Pointer Events
  // ════════════════════════════════════════════════════════
  selectElement(el: CanvasElement, event?: MouseEvent | PointerEvent) {
    if (event) event.stopPropagation();
    this.selectedElementId = el.id;
  }

  deselectAll(event?: MouseEvent) {
    if (this.isInteracting) return;
    this.selectedElementId = null;
  }

  onElementPointerDown(e: PointerEvent, el: CanvasElement) {
    e.stopPropagation();
    this.selectedElementId = el.id;
    if (el.isLocked) return;

    this.isInteracting = true;
    this.interactionType = 'drag';
    this.startPointerX = e.clientX;
    this.startPointerY = e.clientY;
    this.initialElX = el.x;
    this.initialElY = el.y;

    window.addEventListener('pointermove', this.boundPointerMove);
    window.addEventListener('pointerup', this.boundPointerUp);
  }

  onResizeHandlePointerDown(e: PointerEvent, el: CanvasElement, handle: string) {
    e.stopPropagation();
    if (el.isLocked) return;

    this.isInteracting = true;
    this.interactionType = 'resize';
    this.resizeHandle = handle;
    this.startPointerX = e.clientX;
    this.startPointerY = e.clientY;
    this.initialElX = el.x;
    this.initialElY = el.y;
    this.initialElW = el.width;
    this.initialElH = el.height;

    window.addEventListener('pointermove', this.boundPointerMove);
    window.addEventListener('pointerup', this.boundPointerUp);
  }

  private onGlobalPointerMove(e: PointerEvent) {
    if (!this.isInteracting || !this.selectedElement) return;
    const el = this.selectedElement;
    const dx = e.clientX - this.startPointerX;
    const dy = e.clientY - this.startPointerY;

    if (this.interactionType === 'drag') {
      el.x = Math.round(this.initialElX + dx);
      el.y = Math.round(this.initialElY + dy);
    } else if (this.interactionType === 'resize') {
      const minW = 24;
      const minH = 20;

      switch (this.resizeHandle) {
        case 'se':
          el.width = Math.max(minW, Math.round(this.initialElW + dx));
          el.height = Math.max(minH, Math.round(this.initialElH + dy));
          break;
        case 'e':
          el.width = Math.max(minW, Math.round(this.initialElW + dx));
          break;
        case 's':
          el.height = Math.max(minH, Math.round(this.initialElH + dy));
          break;
        case 'sw': {
          const nw = Math.max(minW, Math.round(this.initialElW - dx));
          el.x = this.initialElX + (this.initialElW - nw);
          el.width = nw;
          el.height = Math.max(minH, Math.round(this.initialElH + dy));
          break;
        }
        case 'w': {
          const nw = Math.max(minW, Math.round(this.initialElW - dx));
          el.x = this.initialElX + (this.initialElW - nw);
          el.width = nw;
          break;
        }
        case 'ne': {
          el.width = Math.max(minW, Math.round(this.initialElW + dx));
          const nh = Math.max(minH, Math.round(this.initialElH - dy));
          el.y = this.initialElY + (this.initialElH - nh);
          el.height = nh;
          break;
        }
        case 'n': {
          const nh = Math.max(minH, Math.round(this.initialElH - dy));
          el.y = this.initialElY + (this.initialElH - nh);
          el.height = nh;
          break;
        }
        case 'nw': {
          const nw = Math.max(minW, Math.round(this.initialElW - dx));
          const nh = Math.max(minH, Math.round(this.initialElH - dy));
          el.x = this.initialElX + (this.initialElW - nw);
          el.y = this.initialElY + (this.initialElH - nh);
          el.width = nw;
          el.height = nh;
          break;
        }
      }
    }
  }

  private onGlobalPointerUp() {
    this.isInteracting = false;
    window.removeEventListener('pointermove', this.boundPointerMove);
    window.removeEventListener('pointerup', this.boundPointerUp);
  }

  // ════════════════════════════════════════════════════════
  // Alignment & Layout Helpers
  // ════════════════════════════════════════════════════════
  alignElement(align: 'left' | 'center' | 'right' | 'top' | 'middle' | 'bottom') {
    if (!this.selectedElement) return;
    const el = this.selectedElement;
    const dims = this.getCanvasDims();

    switch (align) {
      case 'left':
        el.x = 8;
        break;
      case 'center':
        el.x = Math.round((dims.width - el.width) / 2);
        break;
      case 'right':
        el.x = dims.width - el.width - 8;
        break;
      case 'top':
        el.y = 8;
        break;
      case 'middle':
        el.y = Math.round((dims.height - el.height) / 2);
        break;
      case 'bottom':
        el.y = dims.height - el.height - 8;
        break;
    }
  }

  applyImagePreset(preset: 'right-avatar' | 'circle-avatar' | 'center-hero' | 'corner-badge') {
    if (!this.selectedElement || this.selectedElement.type !== 'image') return;
    const el = this.selectedElement;
    const dims = this.getCanvasDims();

    if (preset === 'right-avatar') {
      // Exactly matching the second image (Spring Boot Mastery Batch right avatar)
      el.width = Math.round(dims.width * 0.55);
      el.height = Math.round(dims.height * 0.48);
      el.x = dims.width - el.width;
      el.y = dims.height - el.height - (this.canvas.aspectRatio === 'whatsapp' ? 18 : 36);
      el.borderRadius = 0;
      el.objectFit = 'contain';
      el.zIndex = 1;
    } else if (preset === 'circle-avatar') {
      el.width = 90;
      el.height = 90;
      el.x = 20;
      el.y = 180;
      el.borderRadius = 50;
      el.objectFit = 'cover';
    } else if (preset === 'center-hero') {
      el.width = Math.round(dims.width * 0.65);
      el.height = Math.round(dims.height * 0.45);
      el.x = Math.round((dims.width - el.width) / 2);
      el.y = Math.round((dims.height - el.height) / 2);
      el.borderRadius = 12;
      el.objectFit = 'contain';
    } else if (preset === 'corner-badge') {
      el.width = 75;
      el.height = 75;
      el.x = dims.width - 85;
      el.y = 12;
      el.borderRadius = 8;
      el.objectFit = 'contain';
    }
  }

  deleteSelected() {
    if (!this.selectedElementId) return;
    this.elements = this.elements.filter(e => e.id !== this.selectedElementId);
    this.selectedElementId = null;
  }

  bringForward() {
    if (!this.selectedElement) return;
    this.selectedElement.zIndex = (this.selectedElement.zIndex || 1) + 1;
  }

  sendBackward() {
    if (!this.selectedElement) return;
    this.selectedElement.zIndex = Math.max(0, (this.selectedElement.zIndex || 1) - 1);
  }

  resetAllElements() {
    this.elements = [];
    this.selectedElementId = null;
  }

  async exportImg() {
    if (!this.cvsEl?.nativeElement) return;
    // Temporarily deselect element so resize handles/selection border don't get exported
    const prevSel = this.selectedElementId;
    this.selectedElementId = null;

    this.exporting = true;
    this.exportMsg = '';
    try {
      const lib: any = await import('html-to-image' as any);
      const url: string = await lib.toPng(this.cvsEl.nativeElement, { pixelRatio: 3 });
      const a = document.createElement('a');
      a.download = (this.sel?.name || 'post') + '-' + Date.now() + '.png';
      a.href = url;
      a.click();
      this.exportMsg = '✅ Image exported!';
    } catch (err) {
      this.exportMsg = '❌ Export error: ' + (err as any)?.message;
    } finally {
      this.exporting = false;
      this.selectedElementId = prevSel;
      setTimeout(() => this.exportMsg = '', 4000);
    }
  }
}

