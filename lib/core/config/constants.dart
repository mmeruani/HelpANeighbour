class AppCollections {
  static const users = 'users';
  static const publicUsers = 'public_users';
  static const phoneAuthIndex = 'phone_auth_index';
  static const communities = 'communities';
  static const communityMembers = 'community_members';
  static const requests = 'requests';
  static const requestResponses = 'request_responses';
  static const reviews = 'reviews';
  static const notifications = 'notifications';
  static const deviceTokens = 'device_tokens';
  static const activityEvents = 'activity_events';
}

class AppLimits {
  static const profileNameMaxLength = 40;
  static const profileBioMaxLength = 200;

  static const communityNameMaxLength = 50;
  static const communityDescriptionMaxLength = 200;
  static const invitationCodeLength = 8;

  static const requestTitleMaxLength = 100;
  static const requestDescriptionMaxLength = 1000;
  static const requestAddressMaxLength = 200;
  static const customCategoryMaxLength = 40;
  static const contactDetailsMinLength = 5;
  static const contactDetailsMaxLength = 200;
  static const responseCommentMaxLength = 300;

  static const reviewTextMaxLength = 500;
  static const minRating = 1;
  static const maxRating = 5;

  static const rewardMinAmount = 0;
  static const rewardMaxAmount = 1000000;
}
