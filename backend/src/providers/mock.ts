import type { Language, ScamAnalysis } from '../schema.js';
import type { AnalysisProvider, AnalyzeInput } from './types.js';

/**
 * Deterministic, offline provider. Used for:
 *  - local development of the Flutter app with zero API cost,
 *  - automated tests,
 *  - a graceful fallback if you ever want "AI down → still answer something".
 *
 * It is a *very* small keyword heuristic and deliberately looks like one in its
 * wording, so no one mistakes it for a real verdict. (The real offline rule
 * engine from spec §7 Tier 2 will live in the Flutter app, not here.)
 */

interface Signal {
  id: string;
  weight: number;
  pattern: RegExp;
  en: string;
  fr: string;
}

const SIGNALS: Signal[] = [
  {
    id: 'otp_pin',
    weight: 40,
    pattern: /\b(otp|one[- ]time (pass)?code|pin( code)?|code (secret|de confirmation|pin)|mot de passe|password)\b/i,
    en: 'asks for a PIN, OTP or password — legitimate providers never do this',
    fr: 'demande un code PIN, OTP ou mot de passe — les opérateurs légitimes ne le font jamais',
  },
  {
    id: 'send_money',
    weight: 30,
    pattern: /\b(send|transfer|envoie[rz]?|transf[eé]re[rz]?|d[ée]pose[rz]?)\b[^.]{0,40}\b(money|cash|fcfa|xaf|cfa|francs?|momo|orange money|om|argent|frais|fee|fees)\b/i,
    en: 'asks you to send money or pay a fee first',
    fr: 'vous demande d’envoyer de l’argent ou de payer des frais d’abord',
  },
  {
    id: 'prize',
    weight: 25,
    pattern: /\b(congratulations?|f[ée]licitations?|you (have )?won|vous avez gagn[ée]|winner|gagnant|lottery|loterie|prize|prix|bonus|cadeau)\b/i,
    en: 'announces an unexpected prize, bonus or lottery win',
    fr: 'annonce un prix, un bonus ou un gain de loterie inattendu',
  },
  {
    id: 'urgency',
    weight: 15,
    pattern: /\b(urgent(ly)?|immediately|imm[ée]diatement|within \d+ ?(h|hours?|minutes?)|dans les \d+ ?(h|heures?|minutes?)|now|maintenant|expire[sd]?|last chance|derni[eè]re chance|blocked|bloqu[ée]e?|suspended|suspendu)\b/i,
    en: 'creates urgency or pressure to act immediately',
    fr: 'crée un sentiment d’urgence pour vous faire agir immédiatement',
  },
  {
    id: 'account_threat',
    weight: 20,
    pattern: /\b(account|compte)\b[^.]{0,30}\b(locked|lock|blocked|suspend(ed)?|verify|verification|bloqu[ée]|suspendu|v[ée]rifi(er|cation))\b/i,
    en: 'threatens that your account will be locked or needs "verification"',
    fr: 'menace de bloquer votre compte ou exige une « vérification »',
  },
  {
    id: 'link',
    weight: 15,
    pattern: /\b(https?:\/\/|www\.|bit\.ly|tinyurl|t\.co|cutt\.ly|wa\.me)\S*/i,
    en: 'contains a link you are pushed to click',
    fr: 'contient un lien sur lequel on vous pousse à cliquer',
  },
  {
    id: 'job',
    weight: 20,
    pattern: /\b(job offer|remote job|work from home|earn \$?\d+|per day|daily income|offre d.emploi|travail à domicile|gagne[rz]? \d+|par jour|recrutement)\b/i,
    en: 'promises easy or unusually high income',
    fr: 'promet un revenu facile ou anormalement élevé',
  },
  {
    id: 'impersonation',
    weight: 20,
    pattern: /\b(this is|it'?s me|c.est moi|new number|nouveau num[ée]ro|changed my number|j.ai chang[ée] de num[ée]ro|your (son|daughter|mother|father|boss|pastor)|ton (fils|fr[eè]re|p[eè]re|patron))\b/i,
    en: 'looks like someone impersonating a contact or an authority',
    fr: 'ressemble à quelqu’un qui se fait passer pour un proche ou une autorité',
  },
  {
    id: 'wrong_transfer',
    weight: 25,
    pattern: /\b(sent (you )?by mistake|wrong(ly)? (number|transfer)|par erreur|mauvais num[ée]ro|refund|rembourse[rz]?|return the money|renvoie[rz]? l.argent)\b/i,
    en: 'uses the "money sent by mistake, please refund" trick',
    fr: 'utilise l’arnaque du « transfert par erreur, merci de rembourser »',
  },
];

const T = {
  en: {
    safeCategory: 'No Obvious Red Flags',
    suspiciousCategory: 'Suspicious Message',
    scamCategories: {
      otp_pin: 'Mobile Money / PIN Phishing',
      send_money: 'Advance-Fee Scam',
      prize: 'Fake Prize / Lottery Scam',
      account_threat: 'Account Lock Phishing',
      job: 'Fake Job Offer',
      impersonation: 'Impersonation Scam',
      wrong_transfer: 'Wrong-Transfer Refund Scam',
      link: 'Phishing Link',
      urgency: 'Pressure Scam',
    } as Record<string, string>,
    imageOnly: 'A screenshot was provided. In mock mode the image is not read; connect the Gemini provider for real image analysis.',
    empty: 'The message is very short, so there is little to judge.',
    summaryHigh: (n: number) => `This message shows ${n} strong scam indicators. Treat it as a scam.`,
    summaryMedium: 'This message has some warning signs. Be careful and verify before acting.',
    summaryLow: 'No common scam patterns were detected, but stay cautious with unexpected requests.',
    explanationIntro: 'Indicators found (mock heuristic, not AI):',
    explanationNone: 'No known scam keywords or patterns were matched. This does not guarantee the message is safe.',
    actions: {
      high: ['Do not send money, share any PIN/OTP, or click links.', 'Block and report the sender.', 'Verify through an official channel you already know (e.g. dial the operator’s short code).', 'Warn family and friends who may receive the same message.'],
      medium: ['Do not act until you verify the sender through a channel you trust.', 'Never share your PIN, OTP or password.', 'Check the official app or number of the company mentioned.'],
      low: ['Stay alert: never share PIN/OTP codes.', 'If money is requested later, verify by calling the person directly.'],
    },
  },
  fr: {
    safeCategory: 'Aucun signal évident',
    suspiciousCategory: 'Message suspect',
    scamCategories: {
      otp_pin: 'Hameçonnage Mobile Money / PIN',
      send_money: 'Arnaque aux frais anticipés',
      prize: 'Faux prix / Fausse loterie',
      account_threat: 'Hameçonnage « compte bloqué »',
      job: 'Fausse offre d’emploi',
      impersonation: 'Usurpation d’identité',
      wrong_transfer: 'Arnaque au « transfert par erreur »',
      link: 'Lien d’hameçonnage',
      urgency: 'Arnaque par pression',
    } as Record<string, string>,
    imageOnly: 'Une capture d’écran a été fournie. En mode simulation, l’image n’est pas lue ; connectez le fournisseur Gemini pour une vraie analyse d’image.',
    empty: 'Le message est très court, il y a peu d’éléments à évaluer.',
    summaryHigh: (n: number) => `Ce message présente ${n} indicateurs forts d’arnaque. Considérez-le comme une arnaque.`,
    summaryMedium: 'Ce message présente des signaux d’alerte. Soyez prudent et vérifiez avant d’agir.',
    summaryLow: 'Aucun schéma d’arnaque courant détecté, mais restez prudent face aux demandes inattendues.',
    explanationIntro: 'Indicateurs trouvés (heuristique de simulation, pas d’IA) :',
    explanationNone: 'Aucun mot-clé ou schéma d’arnaque connu n’a été détecté. Cela ne garantit pas que le message soit sûr.',
    actions: {
      high: ['N’envoyez pas d’argent, ne partagez aucun code PIN/OTP et ne cliquez sur aucun lien.', 'Bloquez et signalez l’expéditeur.', 'Vérifiez via un canal officiel que vous connaissez déjà (ex. le code court de l’opérateur).', 'Prévenez vos proches qui pourraient recevoir le même message.'],
      medium: ['N’agissez pas avant d’avoir vérifié l’expéditeur par un canal de confiance.', 'Ne partagez jamais votre PIN, OTP ou mot de passe.', 'Consultez l’application ou le numéro officiel de l’entreprise mentionnée.'],
      low: ['Restez vigilant : ne partagez jamais vos codes PIN/OTP.', 'Si de l’argent est demandé plus tard, vérifiez en appelant directement la personne.'],
    },
  },
} satisfies Record<Language, unknown>;

export function mockAnalyze(input: AnalyzeInput): ScamAnalysis {
  const t = T[input.language];
  const text = input.message.trim();
  const matched = SIGNALS.filter((s) => s.pattern.test(text));
  const score = matched.reduce((acc, s) => acc + s.weight, 0);

  let riskLevel: ScamAnalysis['riskLevel'];
  let confidenceScore: number;
  if (score >= 50) {
    riskLevel = 'High';
    confidenceScore = Math.min(95, 60 + score / 3);
  } else if (score >= 20) {
    riskLevel = 'Medium';
    confidenceScore = 55 + score / 2;
  } else {
    riskLevel = 'Low';
    confidenceScore = text.length < 20 ? 40 : 70;
  }

  const top = [...matched].sort((a, b) => b.weight - a.weight)[0];
  const category = riskLevel === 'Low' ? t.safeCategory : top ? (t.scamCategories[top.id] ?? t.suspiciousCategory) : t.suspiciousCategory;

  const lines: string[] = [];
  if (!text) lines.push(t.empty);
  if (input.image) lines.push(t.imageOnly);
  if (matched.length) {
    lines.push(t.explanationIntro);
    for (const s of matched) lines.push(`• ${s[input.language]}`);
  } else {
    lines.push(t.explanationNone);
  }

  const summary = riskLevel === 'High' ? t.summaryHigh(matched.length) : riskLevel === 'Medium' ? t.summaryMedium : t.summaryLow;
  const actions = riskLevel === 'High' ? t.actions.high : riskLevel === 'Medium' ? t.actions.medium : t.actions.low;

  return {
    riskLevel,
    confidenceScore: Math.round(confidenceScore),
    category,
    summary,
    explanation: lines.join('\n'),
    recommendedActions: actions.slice(0, 4),
  };
}

export class MockProvider implements AnalysisProvider {
  readonly name = 'mock' as const;

  async analyze(input: AnalyzeInput): Promise<unknown> {
    return mockAnalyze(input);
  }

  /**
   * Mock "translation": we cannot really translate arbitrary text offline, so
   * we return the analysis unchanged except for a language tag in the summary.
   * Good enough to exercise the client UI flow.
   */
  async translate(analysis: ScamAnalysis, language: Language): Promise<unknown> {
    const tag = language === 'fr' ? '[FR] ' : '[EN] ';
    const strip = (s: string) => s.replace(/^\[(EN|FR)\] /, '');
    return {
      ...analysis,
      category: tag + strip(analysis.category),
      summary: tag + strip(analysis.summary),
      explanation: tag + strip(analysis.explanation),
      recommendedActions: analysis.recommendedActions.map((a) => tag + strip(a)),
    };
  }
}
