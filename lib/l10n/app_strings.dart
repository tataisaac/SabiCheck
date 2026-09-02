import 'package:flutter/widgets.dart';

/// Supported UI languages. Mirrors the backend's `language` field.
enum AppLanguage {
  en('en', 'English', 'EN'),
  fr('fr', 'Français', 'FR');

  const AppLanguage(this.code, this.displayName, this.shortLabel);

  final String code;
  final String displayName;
  final String shortLabel;

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) {
    for (final l in values) {
      if (l.code == code) return l;
    }
    return AppLanguage.en;
  }

  /// Best default for a device locale: French devices get FR, everyone else EN.
  static AppLanguage fromLocale(Locale? locale) =>
      locale?.languageCode.toLowerCase() == 'fr' ? AppLanguage.fr : AppLanguage.en;
}

/// All user-facing copy. Hand-rolled (instead of gen-l10n) to keep the build
/// dependency-free and the two languages side by side for easy review.
class AppStrings {
  const AppStrings._({
    required this.language,
    required this.appName,
    required this.tagline,
    required this.heroTitle,
    required this.heroTitleHighlight,
    required this.heroDescription,
    required this.inputPlaceholder,
    required this.characters,
    required this.analyze,
    required this.analyzing,
    required this.addScreenshot,
    required this.fromGallery,
    required this.takePhoto,
    required this.pasteFromClipboard,
    required this.clipboardEmpty,
    required this.removeImage,
    required this.clear,
    required this.threatAnalysis,
    required this.risk,
    required this.riskLow,
    required this.riskMedium,
    required this.riskHigh,
    required this.confidence,
    required this.suspiciousIndicators,
    required this.readDetailed,
    required this.showLess,
    required this.recommendedAction,
    required this.awaitingTitle,
    required this.awaitingDescription,
    required this.translating,
    required this.sourceCache,
    required this.sourceMock,
    required this.sharedContentReceived,
    required this.sharedImageReceived,
    required this.history,
    required this.historyEmptyTitle,
    required this.historyEmptyDescription,
    required this.historyClearAll,
    required this.historyClearConfirmTitle,
    required this.historyClearConfirmBody,
    required this.historyDeleted,
    required this.imageOnly,
    required this.settings,
    required this.settingsLanguage,
    required this.settingsTheme,
    required this.themeSystem,
    required this.themeLight,
    required this.themeDark,
    required this.settingsApiSection,
    required this.settingsApiUrl,
    required this.settingsApiUrlHint,
    required this.settingsApiUrlHelp,
    required this.settingsApiReset,
    required this.settingsAbout,
    required this.settingsAboutBody,
    required this.settingsPrivacy,
    required this.settingsPrivacyBody,
    required this.builtBy,
    required this.cancel,
    required this.confirm,
    required this.save,
    required this.saved,
    required this.retry,
    required this.close,
    required this.errorEmptyInput,
    required this.errorNetwork,
    required this.errorTimeout,
    required this.errorRateLimited,
    required this.errorUnauthorized,
    required this.errorBadRequest,
    required this.errorPayloadTooLarge,
    required this.errorUpstream,
    required this.errorServer,
    required this.errorImageRead,
    required this.errorImageTooLarge,
    required this.errorUnknown,
  });

  final AppLanguage language;
  final String appName;
  final String tagline;
  final String heroTitle;
  final String heroTitleHighlight;
  final String heroDescription;
  final String inputPlaceholder;
  final String characters;
  final String analyze;
  final String analyzing;
  final String addScreenshot;
  final String fromGallery;
  final String takePhoto;
  final String pasteFromClipboard;
  final String clipboardEmpty;
  final String removeImage;
  final String clear;
  final String threatAnalysis;
  final String risk;
  final String riskLow;
  final String riskMedium;
  final String riskHigh;
  final String confidence;
  final String suspiciousIndicators;
  final String readDetailed;
  final String showLess;
  final String recommendedAction;
  final String awaitingTitle;
  final String awaitingDescription;
  final String translating;
  final String sourceCache;
  final String sourceMock;
  final String sharedContentReceived;
  final String sharedImageReceived;
  final String history;
  final String historyEmptyTitle;
  final String historyEmptyDescription;
  final String historyClearAll;
  final String historyClearConfirmTitle;
  final String historyClearConfirmBody;
  final String historyDeleted;
  final String imageOnly;
  final String settings;
  final String settingsLanguage;
  final String settingsTheme;
  final String themeSystem;
  final String themeLight;
  final String themeDark;
  final String settingsApiSection;
  final String settingsApiUrl;
  final String settingsApiUrlHint;
  final String settingsApiUrlHelp;
  final String settingsApiReset;
  final String settingsAbout;
  final String settingsAboutBody;
  final String settingsPrivacy;
  final String settingsPrivacyBody;
  final String builtBy;
  final String cancel;
  final String confirm;
  final String save;
  final String saved;
  final String retry;
  final String close;
  final String errorEmptyInput;
  final String errorNetwork;
  final String errorTimeout;
  final String errorRateLimited;
  final String errorUnauthorized;
  final String errorBadRequest;
  final String errorPayloadTooLarge;
  final String errorUpstream;
  final String errorServer;
  final String errorImageRead;
  final String errorImageTooLarge;
  final String errorUnknown;

  static AppStrings of(AppLanguage language) => switch (language) {
        AppLanguage.en => en,
        AppLanguage.fr => fr,
      };

  static const en = AppStrings._(
    language: AppLanguage.en,
    appName: 'SabiCheck',
    tagline: 'Know what\'s real.',
    heroTitle: 'Detect digital scams in ',
    heroTitleHighlight: 'seconds',
    heroDescription:
        'Paste a suspicious WhatsApp message, SMS or email — or add a screenshot. SabiCheck checks it for common scam tactics and tells you what to do next.',
    inputPlaceholder:
        'Paste the suspicious message here (e.g. "Congratulations! Your MoMo account has won 500,000 FCFA. Send your PIN to…")',
    characters: 'characters',
    analyze: 'Check message',
    analyzing: 'Checking…',
    addScreenshot: 'Add screenshot',
    fromGallery: 'Choose from gallery',
    takePhoto: 'Take a photo',
    pasteFromClipboard: 'Paste',
    clipboardEmpty: 'Nothing to paste.',
    removeImage: 'Remove image',
    clear: 'Clear',
    threatAnalysis: 'Threat analysis',
    risk: 'RISK',
    riskLow: 'Low',
    riskMedium: 'Medium',
    riskHigh: 'High',
    confidence: 'confidence',
    suspiciousIndicators: 'Suspicious indicators',
    readDetailed: 'Read detailed analysis',
    showLess: 'Show less',
    recommendedAction: 'Recommended actions',
    awaitingTitle: 'Awaiting analysis',
    awaitingDescription:
        'Paste a message or add a screenshot above, then tap "Check message". Tip: from WhatsApp you can also long-press a message → Share → SabiCheck.',
    translating: 'Translating…',
    sourceCache: 'Instant result (seen before)',
    sourceMock: 'Demo mode — offline heuristic, not AI',
    sharedContentReceived: 'Message received. Tap "Check message" to analyze it.',
    sharedImageReceived: 'Screenshot received. Tap "Check message" to analyze it.',
    history: 'History',
    historyEmptyTitle: 'No checks yet',
    historyEmptyDescription: 'Every message you check is saved here on this device so you can look back at it.',
    historyClearAll: 'Clear history',
    historyClearConfirmTitle: 'Clear all history?',
    historyClearConfirmBody: 'This removes all saved checks from this device. It cannot be undone.',
    historyDeleted: 'History cleared.',
    imageOnly: 'Screenshot only',
    settings: 'Settings',
    settingsLanguage: 'Language',
    settingsTheme: 'Appearance',
    themeSystem: 'System',
    themeLight: 'Light',
    themeDark: 'Dark',
    settingsApiSection: 'Developer',
    settingsApiUrl: 'API server URL',
    settingsApiUrlHint: 'https://api.example.com',
    settingsApiUrlHelp:
        'Where SabiCheck sends messages for analysis. Leave the default unless you run your own backend.',
    settingsApiReset: 'Reset to default',
    settingsAbout: 'About SabiCheck',
    settingsAboutBody:
        'SabiCheck is part of the Sabi family of products. "Sabi" is Pidgin for to know — SabiCheck helps you know what\'s real before you send money, share a code or click a link.',
    settingsPrivacy: 'Privacy',
    settingsPrivacyBody:
        'Messages and screenshots you check are sent securely to the SabiCheck server for analysis and are not stored there beyond a short cache. Your history is kept only on this device.',
    builtBy: 'Developed by Tata I. F.',
    cancel: 'Cancel',
    confirm: 'Confirm',
    save: 'Save',
    saved: 'Saved.',
    retry: 'Retry',
    close: 'Close',
    errorEmptyInput: 'Paste a message or add a screenshot first.',
    errorNetwork: 'No connection. Check your internet and try again.',
    errorTimeout: 'The check took too long. Please try again.',
    errorRateLimited: 'Too many checks in a short time. Please wait a moment.',
    errorUnauthorized: 'This app version is not authorised to use the server. Please update the app.',
    errorBadRequest: 'The server rejected the request. Try a shorter message or a smaller screenshot.',
    errorPayloadTooLarge: 'That screenshot is too large. Try a smaller one.',
    errorUpstream: 'The AI service is temporarily unavailable. Please try again shortly.',
    errorServer: 'The server had a problem. Please try again later.',
    errorImageRead: 'Could not read that image.',
    errorImageTooLarge: 'That image is too large (max 5 MB).',
    errorUnknown: 'Something went wrong. Please try again.',
  );

  static const fr = AppStrings._(
    language: AppLanguage.fr,
    appName: 'SabiCheck',
    tagline: 'Sachez ce qui est vrai.',
    heroTitle: 'Détectez les arnaques en quelques ',
    heroTitleHighlight: 'secondes',
    heroDescription:
        'Collez un message WhatsApp, SMS ou e-mail suspect — ou ajoutez une capture d\'écran. SabiCheck y recherche les techniques d\'arnaque courantes et vous dit quoi faire.',
    inputPlaceholder:
        'Collez le message suspect ici (ex. « Félicitations ! Votre compte MoMo a gagné 500 000 FCFA. Envoyez votre code PIN à… »)',
    characters: 'caractères',
    analyze: 'Vérifier le message',
    analyzing: 'Vérification…',
    addScreenshot: 'Ajouter une capture',
    fromGallery: 'Choisir dans la galerie',
    takePhoto: 'Prendre une photo',
    pasteFromClipboard: 'Coller',
    clipboardEmpty: 'Rien à coller.',
    removeImage: 'Retirer l\'image',
    clear: 'Effacer',
    threatAnalysis: 'Analyse de la menace',
    risk: 'RISQUE',
    riskLow: 'Faible',
    riskMedium: 'Moyen',
    riskHigh: 'Élevé',
    confidence: 'de confiance',
    suspiciousIndicators: 'Indicateurs suspects',
    readDetailed: 'Lire l\'analyse détaillée',
    showLess: 'Voir moins',
    recommendedAction: 'Actions recommandées',
    awaitingTitle: 'En attente d\'analyse',
    awaitingDescription:
        'Collez un message ou ajoutez une capture ci-dessus, puis touchez « Vérifier le message ». Astuce : depuis WhatsApp, appuyez longuement sur un message → Partager → SabiCheck.',
    translating: 'Traduction…',
    sourceCache: 'Résultat instantané (déjà vu)',
    sourceMock: 'Mode démo — heuristique hors ligne, pas d\'IA',
    sharedContentReceived: 'Message reçu. Touchez « Vérifier le message » pour l\'analyser.',
    sharedImageReceived: 'Capture reçue. Touchez « Vérifier le message » pour l\'analyser.',
    history: 'Historique',
    historyEmptyTitle: 'Aucune vérification',
    historyEmptyDescription:
        'Chaque message vérifié est enregistré ici, sur cet appareil, pour que vous puissiez le retrouver.',
    historyClearAll: 'Effacer l\'historique',
    historyClearConfirmTitle: 'Effacer tout l\'historique ?',
    historyClearConfirmBody: 'Toutes les vérifications enregistrées sur cet appareil seront supprimées. Action irréversible.',
    historyDeleted: 'Historique effacé.',
    imageOnly: 'Capture uniquement',
    settings: 'Paramètres',
    settingsLanguage: 'Langue',
    settingsTheme: 'Apparence',
    themeSystem: 'Système',
    themeLight: 'Clair',
    themeDark: 'Sombre',
    settingsApiSection: 'Développeur',
    settingsApiUrl: 'URL du serveur API',
    settingsApiUrlHint: 'https://api.exemple.com',
    settingsApiUrlHelp:
        'Adresse à laquelle SabiCheck envoie les messages pour analyse. Laissez la valeur par défaut sauf si vous hébergez votre propre serveur.',
    settingsApiReset: 'Rétablir la valeur par défaut',
    settingsAbout: 'À propos de SabiCheck',
    settingsAboutBody:
        'SabiCheck fait partie de la famille de produits Sabi. « Sabi » signifie savoir en pidgin — SabiCheck vous aide à savoir ce qui est vrai avant d\'envoyer de l\'argent, de partager un code ou de cliquer sur un lien.',
    settingsPrivacy: 'Confidentialité',
    settingsPrivacyBody:
        'Les messages et captures que vous vérifiez sont envoyés de façon sécurisée au serveur SabiCheck pour analyse et n\'y sont pas conservés au-delà d\'un court cache. Votre historique reste uniquement sur cet appareil.',
    builtBy: 'Développé par Tata I. F.',
    cancel: 'Annuler',
    confirm: 'Confirmer',
    save: 'Enregistrer',
    saved: 'Enregistré.',
    retry: 'Réessayer',
    close: 'Fermer',
    errorEmptyInput: 'Collez d\'abord un message ou ajoutez une capture.',
    errorNetwork: 'Pas de connexion. Vérifiez votre accès Internet et réessayez.',
    errorTimeout: 'La vérification a pris trop de temps. Veuillez réessayer.',
    errorRateLimited: 'Trop de vérifications en peu de temps. Patientez un instant.',
    errorUnauthorized: 'Cette version de l\'application n\'est pas autorisée à utiliser le serveur. Mettez-la à jour.',
    errorBadRequest: 'Le serveur a refusé la requête. Essayez un message plus court ou une capture plus petite.',
    errorPayloadTooLarge: 'Cette capture est trop volumineuse. Essayez-en une plus petite.',
    errorUpstream: 'Le service d\'IA est momentanément indisponible. Réessayez dans un instant.',
    errorServer: 'Le serveur a rencontré un problème. Réessayez plus tard.',
    errorImageRead: 'Impossible de lire cette image.',
    errorImageTooLarge: 'Cette image est trop volumineuse (5 Mo max).',
    errorUnknown: 'Une erreur s\'est produite. Veuillez réessayer.',
  );
}
