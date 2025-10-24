export type RootStackParamList = {
  // Auth Flow
  Welcome: undefined;
  Auth: undefined;
  OTPVerification: {
    email?: string;
    phone?: string;
  };
  ProfileSetup: undefined;

  // Main App (coming later)
  MainApp: undefined;
};

declare global {
  namespace ReactNavigation {
    interface RootParamList extends RootStackParamList {}
  }
}
