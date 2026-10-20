"""Countries that field national teams in the tournaments Witness lists (basketball, hockey, handball, baseball).

One row per IOC-style code (FIBA, IIHF, IHF and WBSC use the same codes for these countries):
    CODE | name the catalog shows | ISO 3166-1 alpha-2 | primary | secondary | FIBA zone
Names follow the soccer catalog where it has the country (Bosnia-Herzegovina, Czechia, Congo DR, Ivory Coast); a sport that
already shipped a team for the code keeps its own name (basketball "Turkey", "United Kingdom"). Colors are the flag's, as in the
soccer catalog's tiles; a sport's existing record keeps the colors it already had (jerseys).
FIBA zone: E Europe, A Americas, F Africa, S Asia (with Oceania), used to say which countries a continental championship covers.
"""

TABLE = """
ALB|Albania|AL|D6001C|000000|E
ALG|Algeria|DZ|00873E|FFFFFF|F
ANG|Angola|AO|D6001C|000000|F
ANT|Antigua and Barbuda|AG|D6001C|000000|A
ARG|Argentina|AR|75AADB|FFFFFF|A
ARM|Armenia|AM|D6001C|FF8200|E
AUS|Australia|AU|FFD100|00693E|S
AUT|Austria|AT|D6001C|FFFFFF|E
AZE|Azerbaijan|AZ|0092BC|D6001C|E
BAH|Bahamas|BS|00ABC9|FFD100|A
BAR|Barbados|BB|0054A6|FFD100|A
BDI|Burundi|BI|D6001C|00873E|F
BEL|Belgium|BE|D6001C|FFD100|E
BER|Bermuda|BM|D6001C|0A3161|A
BIH|Bosnia-Herzegovina|BA|0054A6|FFD100|E
BOL|Bolivia|BO|D6001C|00873E|A
BRA|Brazil|BR|FFD100|00A650|A
BRN|Bahrain|BH|D6001C|FFFFFF|S
BUL|Bulgaria|BG|00966E|D6001C|E
CAF|Central African Republic|CF|0054A6|FFD100|F
CAN|Canada|CA|D6001C|FFFFFF|A
CAY|Cayman Islands|KY|0A3161|D6001C|A
CHI|Chile|CL|D6001C|0054A6|A
CHN|China|CN|D6001C|FFD100|S
CIV|Ivory Coast|CI|FF8200|00873E|F
CMR|Cameroon|CM|00873E|D6001C|F
COD|Congo DR|CD|009CDE|FFD100|F
COL|Colombia|CO|FFD100|0054A6|A
CPV|Cape Verde|CV|0054A6|D6001C|F
CRC|Costa Rica|CR|0054A6|D6001C|A
CRO|Croatia|HR|D6001C|0054A6|E
CUB|Cuba|CU|0054A6|D6001C|A
CYP|Cyprus|CY|FFFFFF|D57800|E
CZE|Czechia|CZ|D6001C|0054A6|E
DEN|Denmark|DK|D6001C|FFFFFF|E
DMA|Dominica|DM|00873E|FFD100|A
DOM|Dominican Republic|DO|0054A6|D6001C|A
ECU|Ecuador|EC|FFD100|0054A6|A
EGY|Egypt|EG|D6001C|FFFFFF|F
ESA|El Salvador|SV|0054A6|FFFFFF|A
ESP|Spain|ES|D6001C|FFD100|E
EST|Estonia|EE|0072CE|000000|E
FIJ|Fiji|FJ|68BFE5|0A3161|S
FIN|Finland|FI|0054A6|FFFFFF|E
FRA|France|FR|0054A6|D6001C|E
FRO|Faroe Islands|FO|0054A6|D6001C|E
GAB|Gabon|GA|00873E|FFD100|F
GBR|Great Britain|GB|0A3161|D6001C|E
GEO|Georgia|GE|D6001C|FFFFFF|E
GEQ|Equatorial Guinea|GQ|00873E|D6001C|F
GER|Germany|DE|000000|D6001C|E
GRE|Greece|GR|0054A6|FFFFFF|E
GRN|Grenada|GD|D6001C|FFD100|A
GUA|Guatemala|GT|75AADB|FFFFFF|A
GUI|Guinea|GN|D6001C|FFD100|F
GUM|Guam|GU|0054A6|D6001C|S
GUY|Guyana|GY|00873E|FFD100|A
HAI|Haiti|HT|0054A6|D6001C|A
HKG|Hong Kong|HK|D6001C|FFFFFF|S
HON|Honduras|HN|0054A6|FFFFFF|A
HUN|Hungary|HU|D6001C|00873E|E
INA|Indonesia|ID|D6001C|FFFFFF|S
IND|India|IN|FF8200|00873E|S
IRI|Iran|IR|00873E|D6001C|S
IRL|Ireland|IE|00873E|FF8200|E
IRQ|Iraq|IQ|D6001C|000000|S
ISL|Iceland|IS|0054A6|D6001C|E
ISR|Israel|IL|0054A6|FFFFFF|E
ITA|Italy|IT|0054A6|FFFFFF|E
JAM|Jamaica|JM|FFD100|00873E|A
JOR|Jordan|JO|D6001C|000000|S
JPN|Japan|JP|0054A6|FFFFFF|S
KAZ|Kazakhstan|KZ|00AFCA|FFD100|S
KEN|Kenya|KE|D6001C|00873E|F
KGZ|Kyrgyzstan|KG|D6001C|FFD100|S
KOR|South Korea|KR|D6001C|0054A6|S
KOS|Kosovo|XK|0054A6|FFD100|E
KSA|Saudi Arabia|SA|00873E|FFFFFF|S
KUW|Kuwait|KW|00873E|D6001C|S
LAT|Latvia|LV|9E1B32|FFFFFF|E
LBA|Libya|LY|00873E|D6001C|F
LBN|Lebanon|LB|D6001C|00873E|S
LTU|Lithuania|LT|FFD100|00873E|E
LUX|Luxembourg|LU|D6001C|00A1DE|E
MAD|Madagascar|MG|D6001C|00873E|F
MAR|Morocco|MA|D6001C|00873E|F
MAS|Malaysia|MY|D6001C|0054A6|S
MDV|Maldives|MV|D6001C|00873E|S
MEX|Mexico|MX|00873E|D6001C|A
MGL|Mongolia|MN|D6001C|0054A6|S
MKD|North Macedonia|MK|D6001C|FFD100|E
MLI|Mali|ML|00873E|FFD100|F
MNE|Montenegro|ME|D6001C|FFD100|E
MOZ|Mozambique|MZ|00873E|FFD100|F
NCA|Nicaragua|NI|0054A6|FFFFFF|A
NED|Netherlands|NL|FF8200|0054A6|E
NEP|Nepal|NP|D6001C|0054A6|S
NGR|Nigeria|NG|00873E|FFFFFF|F
NOR|Norway|NO|D6001C|0054A6|E
NZL|New Zealand|NZ|000000|FFFFFF|S
OMA|Oman|OM|D6001C|00873E|S
PAN|Panama|PA|D6001C|0054A6|A
PAR|Paraguay|PY|D6001C|0054A6|A
PHI|Philippines|PH|0054A6|D6001C|S
PLE|Palestine|PS|D6001C|00873E|S
POL|Poland|PL|D6001C|FFFFFF|E
POR|Portugal|PT|D6001C|00873E|E
PUR|Puerto Rico|PR|D6001C|0054A6|A
QAT|Qatar|QA|8A1538|FFFFFF|S
ROU|Romania|RO|FFD100|D6001C|E
RSA|South Africa|ZA|00873E|FFD100|F
RWA|Rwanda|RW|0092CE|FFD100|F
SEN|Senegal|SN|00873E|FFD100|F
SGP|Singapore|SG|D6001C|FFFFFF|S
SLO|Slovenia|SI|0054A6|FFFFFF|E
SRB|Serbia|RS|D6001C|0054A6|E
SRI|Sri Lanka|LK|8D153A|FFD100|S
SSD|South Sudan|SS|D6001C|00873E|F
SUI|Switzerland|CH|D6001C|FFFFFF|E
SVK|Slovakia|SK|0054A6|D6001C|E
SWE|Sweden|SE|0054A6|FFD100|E
SYR|Syria|SY|D6001C|000000|S
TCI|Turks and Caicos Islands|TC|0054A6|FFD100|A
THA|Thailand|TH|0054A6|D6001C|S
TPE|Chinese Taipei|TW|0054A6|D6001C|S
TUN|Tunisia|TN|D6001C|FFFFFF|F
TUR|Turkey|TR|D6001C|FFFFFF|E
UAE|United Arab Emirates|AE|00873E|D6001C|S
UGA|Uganda|UG|FFD100|000000|F
UKR|Ukraine|UA|FFD100|0054A6|E
URU|Uruguay|UY|75AADB|FFFFFF|A
USA|United States|US|0A3161|D6001C|A
VEN|Venezuela|VE|FFD100|0054A6|A
VIE|Vietnam|VN|D6001C|FFD100|S
VIN|St. Vincent and the Grenadines|VC|0054A6|FFD100|A
"""

COUNTRIES = {}
for line in TABLE.strip().splitlines():
    code, name, iso, p, s, zone = line.split("|")
    COUNTRIES[code] = {"name": name, "iso": iso, "primary": p, "secondary": s, "zone": zone}


def lum(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def contrast_on_ink(h):
    ink, l = lum("0B0C10"), lum(h)
    return (max(l, ink) + 0.05) / (min(l, ink) + 0.05)


def accent_for(primary, secondary):
    """The more recognizable of the two colors that stays readable on the app's near-black (contrast >= 3), else a tint."""
    if contrast_on_ink(primary) >= 3.0:
        return primary
    if contrast_on_ink(secondary) >= 3.0:
        return secondary
    p = [int(primary[i:i + 2], 16) for i in (0, 2, 4)]
    for k in range(1, 20):
        t = k * 0.05
        h = "".join(f"{round(c + (255 - c) * t):02X}" for c in p)
        if contrast_on_ink(h) >= 3.0:
            return h
    return "FFFFFF"
