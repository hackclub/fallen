// Who needs a visa for the Shenzhen trip, by passport, for the Visas doc (components/docs/VisaChecker). China changes
// these lists often: CHECKED is when they were last compared with the sources below, and the doc shows it.
//
// Visa free: the unilateral 30-day list (ends December 31, 2026) and the mutual exemption agreements for ordinary
// passports, from the Ministry of Foreign Affairs and the embassies' notices.
// Transit: the 240-hour visa-free transit list (National Immigration Administration) minus the countries above.
// Sources: https://en.nia.gov.cn and https://www.china-briefing.com/news/china-visa-free-travel-policies-complete-guide/
export const CHECKED = 'November 17, 2026'

export type VisaStatus = 'free' | 'transit' | 'visa' | 'permit' | 'citizen'

const UNILATERAL =
  'AD AR AT AU BE BG BH BN BR CA CH CL CY DE DK EE ES FI FR GB GR HR HU IE IS IT JP KR KW LI LU LV MC ME MK MT NL NO NZ OM PE PL PT RO RU SA SE SI SK UY'
const MUTUAL = 'AE AG AL AM AZ BA BB BS BY DM FJ GD GE KZ MU MV MY QA RS SB SC SG SM SR TH TO UZ WS'
const TRANSIT_ONLY = 'CZ ID KG LT MX UA US VN'

// Every passport someone could pick, as ISO 3166 codes. Names come from the browser (Intl.DisplayNames).
const CODES =
  `AD AE AF AG AL AM AO AR AT AU AZ BA BB BD BE BF BG BH BI BJ BN BO BR BS BT BW BY BZ CA CD CF CG CH CI CL CM
  CN CO CR CU CV CY CZ DE DJ DK DM DO DZ EC EE EG ER ES ET FI FJ FM FR GA GB GD GE GH GM GN GQ GR GT GW GY HK HN HR HT HU
  ID IE IL IN IQ IR IS IT JM JO JP KE KG KH KI KM KN KP KR KW KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MG MH MK ML
  MM MN MO MR MT MU MV MW MX MY MZ NA NE NG NI NL NO NP NR NZ OM PA PE PG PH PK PL PS PT PW PY QA RO RS RU RW SA SB SC SD
  SE SG SI SK SL SM SN SO SR SS ST SV SY SZ TD TG TH TJ TL TM TN TO TR TT TV TW TZ UA UG US UY UZ VA VC VE VN VU WS XK YE
  ZA ZM ZW`.split(/\s+/)

// Names people type that the browser's name for the country doesn't contain.
const ALIASES: Record<string, string> = {
  US: 'usa america united states of america',
  GB: 'uk britain great britain england scotland wales northern ireland',
  AE: 'uae emirates dubai',
  KR: 'korea south korea',
  KP: 'korea north korea',
  NL: 'holland',
  CZ: 'czechia',
  CI: 'ivory coast',
  MM: 'burma',
  SZ: 'swaziland',
  MK: 'macedonia',
  TR: 'turkey turkiye',
  CD: 'drc congo',
  CG: 'congo',
  VA: 'vatican holy see',
  PS: 'palestine',
  TW: 'roc',
  CN: 'prc mainland',
}

const NAMES: Record<string, string> = {
  HK: 'Hong Kong',
  MO: 'Macao',
  PS: 'Palestine',
  XK: 'Kosovo',
}

const set = (codes: string) => new Set(codes.split(' '))
const free = new Set([...set(UNILATERAL), ...set(MUTUAL)])
const transit = set(TRANSIT_ONLY)

export type Country = {
  code: string
  name: string
  flag: string
  search: string
  status: VisaStatus
}

const flag = (code: string) =>
  String.fromCodePoint(...[...code].map((letter) => 0x1f1e6 + letter.charCodeAt(0) - 65))

const fold = (text: string) => text.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase()

function status(code: string): VisaStatus {
  if (code === 'CN') return 'citizen'
  if (code === 'HK' || code === 'MO' || code === 'TW') return 'permit'
  if (free.has(code)) return 'free'
  if (transit.has(code)) return 'transit'
  return 'visa'
}

export function countries(): Country[] {
  const display = new Intl.DisplayNames(['en'], { type: 'region' })
  return CODES.map((code) => {
    const name = NAMES[code] ?? display.of(code) ?? code
    return {
      code,
      name,
      flag: flag(code),
      search: fold(`${name} ${code} ${ALIASES[code] ?? ''}`),
      status: status(code),
    }
  }).sort((a, b) => a.name.localeCompare(b.name))
}

// Best matches first: names that start with what was typed, then any word that does, then anywhere.
export function search(list: Country[], query: string): Country[] {
  const q = fold(query.trim())
  if (!q) return list
  const rank = (c: Country) => (c.search.startsWith(q) ? 0 : c.search.includes(` ${q}`) ? 1 : 2)
  return list
    .filter((c) => c.search.includes(q))
    .sort((a, b) => rank(a) - rank(b) || a.name.localeCompare(b.name))
}
