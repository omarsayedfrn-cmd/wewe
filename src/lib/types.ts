// Database types matching Supabase schema

export type Profile = {
  id: string;
  role: 'student' | 'merchant' | 'admin';
  grade: string | null;
  track: string | null;
  language: 'ar' | 'en';
  display_name: string | null;
  avatar: string | null;
  referral_code: string;
  referred_by: string | null;
  trial_used: boolean;
  onboard_locked: boolean;
  approved: boolean;
  approved_at: string | null;
  platform_login: string | null;
  platform_login_norm: string | null;
  platform_bound_at: string | null;
  created_at: string;
};

export type Engine = {
  code: string;
  name_ar: string;
  name_en: string;
  platform: string;
  course: string;
  language: 'ar' | 'en';
  max_chapter: number;
};

export type Entitlement = {
  id: string;
  user_id: string;
  engine_code: string;
  scope: 'full' | 'chapter';
  chapters: number[];
  source: 'trial' | 'purchase' | 'gift';
  created_at: string;
  expires_at: string | null;
};

export type Product = {
  id: string;
  name: string;
  coins: number;
  price: number;
  active: boolean;
  sort: number;
};

export type Pricing = {
  engine_code: string;
  kind: 'full' | 'chapter';
  cost: number;
};

export type Wallet = {
  user_id: string;
  balance: number;
};

export type WalletTransaction = {
  id: string;
  user_id: string;
  delta: number;
  reason: string;
  ref_id: string | null;
  created_at: string;
};

export type SupportThread = {
  id: string;
  user_id: string;
  status: 'open' | 'closed';
  last_message_at: string | null;
  unread_admin: number;
  unread_user: number;
  created_at: string;
  // Joined
  profiles?: Profile;
};

export type SupportMessage = {
  id: string;
  thread_id: string;
  sender_role: 'user' | 'admin';
  body: string;
  created_at: string;
};

export type NotificationKind = 'info' | 'warning' | 'success';

export type Notification = {
  id: string;
  user_id: string;
  broadcast_id: string;
  title: string;
  body: string;
  kind: NotificationKind;
  is_read: boolean;
  created_by: string | null;
  created_at: string;
};

export type Setting = {
  key: string;
  value: string | number | Record<string, unknown>;
};

export type AuditLog = {
  id: string;
  admin_id: string;
  action: string;
  payload: Record<string, unknown> | null;
  created_at: string;
  profiles?: Profile;
};

// Labels
export const gradeLabels: Record<string, string> = {
  grade_1: 'أولى ثانوي',
  grade_2: 'تانية ثانوي',
};

export const trackLabels: Record<string, string> = {
  medicine: 'الطب والعلوم الحيوية',
  business: 'إدارة الأعمال',
  arts: 'الآداب والفنون',
  engineering: 'الهندسة وعلوم الحاسب',
};

export const languageLabels: Record<string, string> = {
  ar: 'عام',
  en: 'لغات',
};

export const roleLabels: Record<string, string> = {
  student: 'طالب',
  merchant: 'تاجر',
  admin: 'أدمن',
};

export const reasonLabels: Record<string, string> = {
  purchase: 'شراء',
  recharge: 'شحن',
  referral_signup: 'مكافأة إحالة (تسجيل)',
  referral_recharge: 'مكافأة إحالة (شحن)',
  admin_grant: 'منحة من الإدارة',
};
