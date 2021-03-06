;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Base: 10; coding: iso-8859-1 -*-
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;          Copyright � 2002 ChangeSafe, LLC
;;;;          ALL RIGHTS RESERVED.
;;;;
;;;;          ChangeSafe, LLC CONFIDENTIAL and PROPRIETARY material.
;;;;
;;;;          ChangeSafe, LLC
;;;;
;;;; This software and information comprise valuable intellectual
;;;; property and trade secrets of ChangeSafe, LLC, developed at
;;;; substantial expense by ChangeSafe, which ChangeSafe intends to
;;;; preserve as trade secrets.  This software is furnished pursuant
;;;; to a written license agreement and may be used, copied,
;;;; transmitted, and stored only in accordance with the terms of such
;;;; license and with the inclusion of the above copyright notice.
;;;; This software and information or any other copies thereof may not
;;;; be provided or otherwise made available to any other person.  NO
;;;; title to or ownership of this software and information is hereby
;;;; transferred.  ChangeSafe, LLC assumes no responsibility for the
;;;; use or reliability of this software.
;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package "CSF/UTILITY")

(eval-when (:load-toplevel :execute)
  (export '(iso-3166-record/code
            iso-3166-record/english-name
            iso-3166-record/french-name
            parse-iso-3166-code)))

(proclaim (standard-optimizations))

(defconstant *iso-3166-records* 
  (if (and (boundp '*iso-3166-records*)
           (symbol-value '*iso-3166-records*))
      (symbol-value '*iso-3166-records*)
      (make-hash-table :test #'eq)))

(defun parse-iso-3166-code (string)
  (check-type string string)
  (let ((code (find-keyword (string-upcase string))))
    (and code (gethash code *iso-3166-records*))))

(defclass iso-3166-record ()
  ((english-name :initarg :english-name
                 :reader iso-3166/english-name)
   (french-name  :initarg :french-name
                 :reader iso-3166/french-name)
   (code         :initarg :code
                 :reader iso-3166/code)
   (string-table :initform (make-hash-table :test #'eq)
                 :reader iso-3166/string-table)
   (formatter-table :initform (make-hash-table :test #'eq)
                    :reader iso-3166/formatter-table)))

(defmethod initialize-instance :after ((instance iso-3166-record) &key code &allow-other-keys)
  (setf (gethash code *iso-3166-records*) instance))

(defmethod print-object ((record iso-3166-record) stream)
  (print-unreadable-object (record stream)
    (format stream "ISO3166 Country ~a ~a"
            (symbol-name (iso-3166/code record))
            (iso-3166/english-name record))))

(defun iso-3166/country-string (iso-3166-record string-identifier)
  (check-type iso-3166-record iso-3166-record)
  (check-type string-identifier keyword)
  (gethash string-identifier (iso-3166/string-table iso-3166-record)))

(defun iso-3166/set-country-string (iso-3166-record string-identifier new-value)
  (check-type iso-3166-record iso-3166-record)
  (check-type string-identifier keyword)
  (check-type new-value string)
  (setf (gethash string-identifier (iso-3166/string-table iso-3166-record)) new-value))

(defsetf iso-3166/country-string (iso-3166-record string-identifier) (new-value)
  `(ISO-3166/SET-COUNTRY-STRING ,iso-3166-record ,string-identifier ,new-value))

(defun iso-3166/country-formatter (iso-3166-record formatter-identifier)
  (check-type iso-3166-record iso-3166-record)
  (check-type formatter-identifier keyword)
  (gethash formatter-identifier (iso-3166/formatter-table iso-3166-record)))

(defun iso-3166/set-country-formatter (iso-3166-record formatter-identifier new-value)
  (check-type iso-3166-record iso-3166-record)
  (check-type formatter-identifier keyword)
  (setf (gethash formatter-identifier (iso-3166/formatter-table iso-3166-record)) new-value))

(defsetf iso-3166/country-formatter (iso-3166-record formatter-identifier) (new-value)
  `(ISO-3166/SET-COUNTRY-FORMATTER ,iso-3166-record ,formatter-identifier ,new-value))

(eval-when (:load-toplevel :execute)
  (mapc (lambda (record)
          (make-instance 'iso-3166-record 
                         :code (first record)
                         :english-name (second record)
                         :french-name (third record)))
        '((:AD "ANDORRA" "ANDORRE")
          (:AE "UNITED ARAB EMIRATES" "�MIRATS ARABES UNIS")
          (:AF "AFGHANISTAN" "AFGHANISTAN")
          (:AG "ANTIGUA AND BARBUDA" "ANTIGUA-ET-BARBUDA")
          (:AI "ANGUILLA" "ANGUILLA")
          (:AL "ALBANIA" "ALBANIE")
          (:AM "ARMENIA" "ARM�NIE")
          (:AN "NETHERLANDS ANTILLES" "ANTILLES N�ERLANDAISES")
          (:AO "ANGOLA" "ANGOLA")
          (:AQ "ANTARCTICA" "ANTARCTIQUE")
          (:AR "ARGENTINA" "ARGENTINE")
          (:AS "AMERICAN SAMOA" "SAMOA AM�RICAINES")
          (:AT "AUSTRIA" "AUTRICHE")
          (:AU "AUSTRALIA" "AUSTRALIE")
          (:AW "ARUBA" "ARUBA")
          (:AZ "AZERBAIJAN" "AZERBA�DJAN")
          (:BA "BOSNIA AND HERZEGOVINA" "BOSNIE-HERZ�GOVINE")
          (:BB "BARBADOS" "BARBADE")
          (:BD "BANGLADESH" "BANGLADESH")
          (:BE "BELGIUM" "BELGIQUE")
          (:BF "BURKINA FASO" "BURKINA FASO")
          (:BG "BULGARIA" "BULGARIE")
          (:BH "BAHRAIN" "BAHRE�N")
          (:BI "BURUNDI" "BURUNDI")
          (:BJ "BENIN" "B�NIN")
          (:BM "BERMUDA" "BERMUDES")
          (:BN "BRUNEI DARUSSALAM" "BRUN�I DARUSSALAM")
          (:BO "BOLIVIA" "BOLIVIE")
          (:BR "BRAZIL" "BR�SIL")
          (:BS "BAHAMAS" "BAHAMAS")
          (:BT "BHUTAN" "BHOUTAN")
          (:BV "BOUVET ISLAND" "BOUVET, �LE")
          (:BW "BOTSWANA" "BOTSWANA")
          (:BY "BELARUS" "B�LARUS")
          (:BZ "BELIZE" "BELIZE")
          (:CA "CANADA" "CANADA")
          (:CC "COCOS (KEELING) ISLANDS" "COCOS (KEELING), �LES")
          (:CD "CONGO, THE DEMOCRATIC REPUBLIC OF THE" "CONGO, LA R�PUBLIQUE D�MOCRATIQUE DU")
          (:CF "CENTRAL AFRICAN REPUBLIC" "CENTRAFRICAINE, R�PUBLIQUE")
          (:CG "CONGO" "CONGO")
          (:CH "SWITZERLAND" "SUISSE")
          (:CI "COTE D'IVOIRE" "C�TE D'IVOIRE")
          (:CK "COOK ISLANDS" "COOK, �LES")
          (:CL "CHILE" "CHILI")
          (:CM "CAMEROON" "CAMEROUN")
          (:CN "CHINA" "CHINE")
          (:CO "COLOMBIA" "COLOMBIE")
          (:CR "COSTA RICA" "COSTA RICA")
          (:CS "SERBIA AND MONTENEGRO" "SERBIE-ET-MONT�N�GRO")
          (:CU "CUBA" "CUBA")
          (:CV "CAPE VERDE" "CAP-VERT")
          (:CX "CHRISTMAS ISLAND" "CHRISTMAS, �LE")
          (:CY "CYPRUS" "CHYPRE")
          (:CZ "CZECH REPUBLIC" "TCH�QUE, R�PUBLIQUE")
          (:DE "GERMANY" "ALLEMAGNE")
          (:DJ "DJIBOUTI" "DJIBOUTI")
          (:DK "DENMARK" "DANEMARK")
          (:DM "DOMINICA" "DOMINIQUE")
          (:DO "DOMINICAN REPUBLIC" "DOMINICAINE, R�PUBLIQUE")
          (:DZ "ALGERIA" "ALG�RIE")
          (:EC "ECUADOR" "�QUATEUR")
          (:EE "ESTONIA" "ESTONIE")
          (:EG "EGYPT" "�GYPTE")
          (:EH "WESTERN SAHARA" "SAHARA OCCIDENTAL")
          (:ER "ERITREA" "�RYTHR�E")
          (:ES "SPAIN" "ESPAGNE")
          (:ET "ETHIOPIA" "�THIOPIE")
          (:FI "FINLAND" "FINLANDE")
          (:FJ "FIJI" "FIDJI")
          (:FK "FALKLAND ISLANDS (MALVINAS)" "FALKLAND, �LES (MALVINAS)")
          (:FM "MICRONESIA, FEDERATED STATES OF" "MICRON�SIE, �TATS F�D�R�S DE")
          (:FO "FAROE ISLANDS" "F�RO�, �LES")
          (:FR "FRANCE" "FRANCE")
          (:GA "GABON" "GABON")
          (:GB "UNITED KINGDOM" "ROYAUME-UNI")
          (:GD "GRENADA" "GRENADE")
          (:GE "GEORGIA" "G�ORGIE")
          (:GF "FRENCH GUIANA" "GUYANE FRAN�AISE")
          (:GH "GHANA" "GHANA")
          (:GI "GIBRALTAR" "GIBRALTAR")
          (:GL "GREENLAND" "GROENLAND")
          (:GM "GAMBIA" "GAMBIE")
          (:GN "GUINEA" "GUIN�E")
          (:GP "GUADELOUPE" "GUADELOUPE")
          (:GQ "EQUATORIAL GUINEA" "GUIN�E �QUATORIALE")
          (:GR "GREECE" "GR�CE")
          (:GS "SOUTH GEORGIA AND THE SOUTH SANDWICH ISLANDS" "G�ORGIE DU SUD ET LES �LES SANDWICH DU SUD")
          (:GT "GUATEMALA" "GUATEMALA")
          (:GU "GUAM" "GUAM")
          (:GW "GUINEA-BISSAU" "GUIN�E-BISSAU")
          (:GY "GUYANA" "GUYANA")
          (:HK "HONG KONG" "HONG-KONG")
          (:HM "HEARD ISLAND AND MCDONALD ISLANDS" "HEARD, �LE ET MCDONALD, �LES")
          (:HN "HONDURAS" "HONDURAS")
          (:HR "CROATIA" "CROATIE")
          (:HT "HAITI" "HA�TI")
          (:HU "HUNGARY" "HONGRIE")
          (:ID "INDONESIA" "INDON�SIE")
          (:IE "IRELAND" "IRLANDE")
          (:IL "ISRAEL" "ISRA�L")
          (:IN "INDIA" "INDE")
          (:IO "BRITISH INDIAN OCEAN TERRITORY" "OC�AN INDIEN, TERRITOIRE BRITANNIQUE DE L'")
          (:IQ "IRAQ" "IRAQ")
          (:IR "IRAN, ISLAMIC REPUBLIC OF" "IRAN, R�PUBLIQUE ISLAMIQUE D'")
          (:IS "ICELAND" "ISLANDE")
          (:IT "ITALY" "ITALIE")
          (:JM "JAMAICA" "JAMA�QUE")
          (:JO "JORDAN" "JORDANIE")
          (:JP "JAPAN" "JAPON")
          (:KE "KENYA" "KENYA")
          (:KG "KYRGYZSTAN" "KIRGHIZISTAN")
          (:KH "CAMBODIA" "CAMBODGE")
          (:KI "KIRIBATI" "KIRIBATI")
          (:KM "COMOROS" "COMORES")
          (:KN "SAINT KITTS AND NEVIS" "SAINT-KITTS-ET-NEVIS")
          (:KP "KOREA, DEMOCRATIC PEOPLE'S REPUBLIC OF" "COR�E, R�PUBLIQUE POPULAIRE D�MOCRATIQUE DE")
          (:KR "KOREA, REPUBLIC OF" "COR�E, R�PUBLIQUE DE")
          (:KW "KUWAIT" "KOWE�T")
          (:KY "CAYMAN ISLANDS" "CA�MANES, �LES")
          (:KZ "KAZAKHSTAN" "KAZAKHSTAN")
          (:LA "LAO PEOPLE'S DEMOCRATIC REPUBLIC" "LAO, R�PUBLIQUE D�MOCRATIQUE POPULAIRE")
          (:LB "LEBANON" "LIBAN")
          (:LC "SAINT LUCIA" "SAINTE-LUCIE")
          (:LI "LIECHTENSTEIN" "LIECHTENSTEIN")
          (:LK "SRI LANKA" "SRI LANKA")
          (:LR "LIBERIA" "LIB�RIA")
          (:LS "LESOTHO" "LESOTHO")
          (:LT "LITHUANIA" "LITUANIE")
          (:LU "LUXEMBOURG" "LUXEMBOURG")
          (:LV "LATVIA" "LETTONIE")
          (:LY "LIBYAN ARAB JAMAHIRIYA" "LIBYENNE, JAMAHIRIYA ARABE")
          (:MA "MOROCCO" "MAROC")
          (:MC "MONACO" "MONACO")
          (:MD "MOLDOVA, REPUBLIC OF" "MOLDOVA, R�PUBLIQUE DE")
          (:MG "MADAGASCAR" "MADAGASCAR")
          (:MH "MARSHALL ISLANDS" "MARSHALL, �LES")
          (:MK "MACEDONIA, THE FORMER YUGOSLAV REPUBLIC OF" "MAC�DOINE, L'EX-R�PUBLIQUE YOUGOSLAVE DE")
          (:ML "MALI" "MALI")
          (:MM "MYANMAR" "MYANMAR")
          (:MN "MONGOLIA" "MONGOLIE")
          (:MO "MACAO" "MACAO")
          (:MP "NORTHERN MARIANA ISLANDS" "MARIANNES DU NORD, �LES")
          (:MQ "MARTINIQUE" "MARTINIQUE")
          (:MR "MAURITANIA" "MAURITANIE")
          (:MS "MONTSERRAT" "MONTSERRAT")
          (:MT "MALTA" "MALTE")
          (:MU "MAURITIUS" "MAURICE")
          (:MV "MALDIVES" "MALDIVES")
          (:MW "MALAWI" "MALAWI")
          (:MX "MEXICO" "MEXIQUE")
          (:MY "MALAYSIA" "MALAISIE")
          (:MZ "MOZAMBIQUE" "MOZAMBIQUE")
          (:NA "NAMIBIA" "NAMIBIE")
          (:NC "NEW CALEDONIA" "NOUVELLE-CAL�DONIE")
          (:NE "NIGER" "NIGER")
          (:NF "NORFOLK ISLAND" "NORFOLK, �LE")
          (:NG "NIGERIA" "NIG�RIA")
          (:NI "NICARAGUA" "NICARAGUA")
          (:NL "NETHERLANDS" "PAYS-BAS")
          (:NO "NORWAY" "NORV�GE")
          (:NP "NEPAL" "N�PAL")
          (:NR "NAURU" "NAURU")
          (:NU "NIUE" "NIU�")
          (:NZ "NEW ZEALAND" "NOUVELLE-Z�LANDE")
          (:OM "OMAN" "OMAN")
          (:PA "PANAMA" "PANAMA")
          (:PE "PERU" "P�ROU")
          (:PF "FRENCH POLYNESIA" "POLYN�SIE FRAN�AISE")
          (:PG "PAPUA NEW GUINEA" "PAPOUASIE-NOUVELLE-GUIN�E")
          (:PH "PHILIPPINES" "PHILIPPINES")
          (:PK "PAKISTAN" "PAKISTAN")
          (:PL "POLAND" "POLOGNE")
          (:PM "SAINT PIERRE AND MIQUELON" "SAINT-PIERRE-ET-MIQUELON")
          (:PN "PITCAIRN" "PITCAIRN")
          (:PR "PUERTO RICO" "PORTO RICO")
          (:PS "PALESTINIAN TERRITORY, OCCUPIED" "PALESTINIEN OCCUP�, TERRITOIRE")
          (:PT "PORTUGAL" "PORTUGAL")
          (:PW "PALAU" "PALAOS")
          (:PY "PARAGUAY" "PARAGUAY")
          (:QA "QATAR" "QATAR")
          (:RE "REUNION" "R�UNION")
          (:RO "ROMANIA" "ROUMANIE")
          (:RU "RUSSIAN FEDERATION" "RUSSIE, F�D�RATION DE")
          (:RW "RWANDA" "RWANDA")
          (:SA "SAUDI ARABIA" "ARABIE SAOUDITE")
          (:SB "SOLOMON ISLANDS" "SALOMON, �LES")
          (:SC "SEYCHELLES" "SEYCHELLES")
          (:SD "SUDAN" "SOUDAN")
          (:SE "SWEDEN" "SU�DE")
          (:SG "SINGAPORE" "SINGAPOUR")
          (:SH "SAINT HELENA" "SAINTE-H�L�NE")
          (:SI "SLOVENIA" "SLOV�NIE")
          (:SJ "SVALBARD AND JAN MAYEN" "SVALBARD ET �LE JAN MAYEN")
          (:SK "SLOVAKIA" "SLOVAQUIE")
          (:SL "SIERRA LEONE" "SIERRA LEONE")
          (:SM "SAN MARINO" "SAINT-MARIN")
          (:SN "SENEGAL" "S�N�GAL")
          (:SO "SOMALIA" "SOMALIE")
          (:SR "SURINAME" "SURINAME")
          (:ST "SAO TOME AND PRINCIPE" "SAO TOM�-ET-PRINCIPE")
          (:SV "EL SALVADOR" "EL SALVADOR")
          (:SY "SYRIAN ARAB REPUBLIC" "SYRIENNE, R�PUBLIQUE ARABE")
          (:SZ "SWAZILAND" "SWAZILAND")
          (:TC "TURKS AND CAICOS ISLANDS" "TURKS ET CA�QUES, �LES")
          (:TD "CHAD" "TCHAD")
          (:TF "FRENCH SOUTHERN TERRITORIES" "TERRES AUSTRALES FRAN�AISES")
          (:TG "TOGO" "TOGO")
          (:TH "THAILAND" "THA�LANDE")
          (:TJ "TAJIKISTAN" "TADJIKISTAN")
          (:TK "TOKELAU" "TOKELAU")
          (:TL "TIMOR-LESTE" "TIMOR-LESTE")
          (:TM "TURKMENISTAN" "TURKM�NISTAN")
          (:TN "TUNISIA" "TUNISIE")
          (:TO "TONGA" "TONGA")
          (:TR "TURKEY" "TURQUIE")
          (:TT "TRINIDAD AND TOBAGO" "TRINIT�-ET-TOBAGO")
          (:TV "TUVALU" "TUVALU")
          (:TW "TAIWAN, PROVINCE OF CHINA" "TA�WAN, PROVINCE DE CHINE")
          (:TZ "TANZANIA, UNITED REPUBLIC OF" "TANZANIE, R�PUBLIQUE-UNIE DE")
          (:UA "UKRAINE" "UKRAINE")
          (:UG "UGANDA" "OUGANDA")
          (:UM "UNITED STATES MINOR OUTLYING ISLANDS" "�LES MINEURES �LOIGN�ES DES �TATS-UNIS")
          (:US "UNITED STATES" "�TATS-UNIS")
          (:UY "URUGUAY" "URUGUAY")
          (:UZ "UZBEKISTAN" "OUZB�KISTAN")
          (:VA "HOLY SEE (VATICAN CITY STATE)" "SAINT-SI�GE (�TAT DE LA CIT� DU VATICAN)")
          (:VC "SAINT VINCENT AND THE GRENADINES" "SAINT-VINCENT-ET-LES GRENADINES")
          (:VE "VENEZUELA" "VENEZUELA")
          (:VG "VIRGIN ISLANDS, BRITISH" "�LES VIERGES BRITANNIQUES")
          (:VI "VIRGIN ISLANDS, U.S." "�LES VIERGES DES �TATS-UNIS")
          (:VN "VIET NAM" "VIET NAM")
          (:VU "VANUATU" "VANUATU")
          (:WF "WALLIS AND FUTUNA" "WALLIS ET FUTUNA")
          (:WS "SAMOA" "SAMOA")
          (:YE "YEMEN" "Y�MEN")
          (:YT "MAYOTTE" "MAYOTTE")
          (:ZA "SOUTH AFRICA" "AFRIQUE DU SUD")
          (:ZM "ZAMBIA" "ZAMBIE")
          (:ZW "ZIMBABWE" "ZIMBABWE"))))
