;; ##############################################
;; ### DECLARATIONS GLOBALES ET PARAMETRES ###
;; ##############################################

globals [


  nombre-agents
  simulation-en-cours
  probabilite-ajout
  taux-divorce
  impact-autonomie
  impact-absence
  impact-economique

  ; Statistiques avancées
  total-impact-violence
  total-impact-intrusion
  total-impact-reseaux
  total-impact-autonomie
  total-impact-absence
  total-impact-economique
  total-impact-culturel
]

turtles-own [
  genre
  age
  residence
  couleur
  facteurs
  conjoint
  etat-matrimonial
  facteurs_culturels
  facteurs_individuels
  has_child
  experience-divorce

  ; Nouveaux attributs
  violence-subie
  intrusion-famille
  reseaux-sociaux
  autonomie-financiere
  temps-absence
  revenu_epou
  revenu_epouxe
  religion_epou
  religion_epouxe

  impact-violence     ; Doit être déclaré
  impact-intrusion    ; Doit être déclaré
  impact-reseaux      ; Doit être déclaré


]

;; ##############################
;; ### PROCEDURES PRINCIPALES ###
;; ##############################

to setup
  clear-all
  set simulation-en-cours true
  set probabilite-ajout 0.1

  create-turtles nombre_agents [
    initialiser-agent
  ]

  reset-ticks
  output-print "Simulation initialisée avec succès!"
end

to initialiser-agent
  set shape "person"
  set genre one-of ["homme" "femme"]
  set age random 60 + 20
  set residence ifelse-value (residence-switch) ["urbain"] ["rural"]
  set color ifelse-value (genre = "homme") [blue] [pink]

  ; Initialisation des caractéristiques socio-économiques
  set revenu_epou random 15000 + 3000
  set revenu_epouxe random 12000 + 3000
  set education_epou one-of ["Analphabétisme" "Éducation de base" "Enseignement supérieur"]
  set education_epouxe one-of ["Analphabétisme" "Éducation de base" "Enseignement supérieur"]

  ; Nouveaux facteurs dynamiques
  set violence-subie (random-float 100 < Proba-violence)
  set intrusion-famille random-normal (Intrusion-familiale / 2) 0.5
 set reseaux-sociaux
  ifelse-value (Exposition-réseaux-sociaux = "Bas")
  [ 0.1 ]
  [ ifelse-value (Exposition-réseaux-sociaux = "Moyen")
    [ 0.3 ]
    [ ifelse-value (Exposition-réseaux-sociaux = "Haut")
      [ 0.6 ]
      [ 0 ] ; Valeur par défaut si aucune option ne correspond
    ]
  ]
  set autonomie-financiere (revenu_epouxe > Seuil-autonomie-femme)

  ; Migration
  if Migration-active? and (random 100 < 15) [
    set temps-absence random 50
  ]

  move-to one-of patches
end

to go
  if not simulation-en-cours [ stop ]
   if random-float 1 < probabilite-ajout [
     create-turtles 1 [
    initialiser-agent
  ]
  ]
  ;; Déplacer cette partie EN DEHORS du ask turtles
  mettre-a-jour-facteurs  ; Appel unique par l'observateur
  calculer-impacts        ; Appel unique par l'observateur

  ask turtles [           ; Un seul ask turtles global
    if etat-matrimonial = "marié" [ verifier-divorce ]
    if color != green [ move ]
     if color != red [
      check-for-marriage
    ]
  ]
    collecter-donnees

  tick
end
to check-for-marriage
  ; Recherche avec un rayon limité pour réduire la charge
 let candidate one-of other turtles in-radius 2 with [
    color != [color] of myself and color != green and color != red
  ]
  if candidate != nobody [


    if (color != red)
    [
      set color green
      set conjoint candidate
      set etat-matrimonial "marié"
      set has_child one-of [true false]
      ask candidate [
        set color green
        set conjoint myself
        set etat-matrimonial "marié"
      ]
    ]
  ]
end

;; ##############################
;; ### MOUVEMENT DES AGENTS ###
;; ##############################

to move
  ; Déplacement aléatoire avec contraintes réalistes
  ifelse residence = "urbain" [
    ; Mouvement plus rapide en milieu urbain
    rt random 50 - 25  ; Rotation aléatoire entre -25° et +25°
    fd random-float 1.5 + 0.5 ; Vitesse entre 0.5 et 2.0
  ][
    ; Mouvement plus lent en milieu rural
    rt random 30 - 15
    fd random-float 0.8 + 0.2 ; Vitesse entre 0.2 et 1.0
  ]

  ; Éviter les bords de l'environnement
  if abs pxcor > max-pxcor - 2 [ set heading (- heading) ]
  if abs pycor > max-pycor - 2 [ set heading (- heading) ]

  ; Vieillissement réaliste
  if ticks mod 365 = 0 [  ; Vieillir d'un an chaque année simulée
    set age age + 1
  ]
end
;; #################################
;; ### MECANISMES DE DIVORCE ###
;; #################################

to verifier-divorce
  let score calculer-score-divorce
  if score > 0.65 [ ; Seuil ajustable
    divorcer
    output-print (word "Divorce! Score: " precision score 2)
  ]
end
;; ################################
;; ### PROCÉDURE DE DIVORCE ###
;; ################################

to divorcer
  ; Changement d'état matrimonial
  set color red
  set etat-matrimonial "divorcé"
  set experience-divorce true

  ; Gestion des enfants (selon le Code de la famille marocain)
  if (genre = "femme" and autonomie-financiere) [
    ; 30% de chance de garde si la femme est autonome
    set has_child (random-float 1 < 0.3)
  ]

  ; Mise à jour du conjoint
  if is-turtle? conjoint [
    ask conjoint [
      set color red
      set etat-matrimonial "divorcé"
      set experience-divorce true
      set conjoint nobody

      ; Perte potentielle des enfants pour l'homme
      if (genre = "homme") [
        set has_child false
      ]
    ]
  ]

  ; Réinitialisation des liens conjugaux
  set conjoint nobody

  ; Impact sur la communauté (voisinage)
  ask turtles in-radius 3 [ ; Rayon de 3 patches
    if self != myself and random-float 1 < 0.2 [ ; Éviter soi-même
      set facteurs_culturels (facteurs_culturels + 0.1) ; OK car turtle-own
    ]
  ]
end
to-report calculer-score-divorce
  if conjoint = nobody [ report 0 ]

  let score (
  (impact-violence * 0.4) +
  (impact-intrusion * 0.3) +
  (impact-reseaux * 0.25) +
  (impact-autonomie * 0.35) +
  (impact-absence * 0.3) +
  (impact-economique * 0.45)
)


  ; Enregistrement des impacts pour statistiques
  set total-impact-violence (total-impact-violence + impact-violence)
  set total-impact-intrusion (total-impact-intrusion + impact-intrusion)
  ; ... [Même principe pour les autres facteurs]

  report min list (score * 1.5) 1 ; Normalisation
end

;; ################################
;; ### CALCULATEURS D'IMPACT ###
;; ################################

to-report impact-violences
  ifelse (conjoint != nobody and is-turtle? conjoint) [
    let v-conjoint [violence-subie] of conjoint
    report ifelse-value (violence-subie or v-conjoint)
      [1.0 + (0.2 * niveau-féminisme-numerique)]
      [0]
  ][
    report ifelse-value violence-subie [1.0] [0]
  ]
end

to-report impact-intrusions
  ifelse (conjoint != nobody and is-turtle? conjoint) [
    let i-conjoint [intrusion-famille] of conjoint
    report ((intrusion-famille + i-conjoint) / 20 * (facteurs_culturels / 100))
  ][
    report (intrusion-famille / 20 * (facteurs_culturels / 100))
  ]
end

to-report impact-reseau
  ifelse (conjoint != nobody and is-turtle? conjoint) [
    let r-conjoint [reseaux-sociaux] of conjoint
    report (reseaux-sociaux * r-conjoint * 0.8)
  ][
    report (reseaux-sociaux * 0.8)
  ]
end

to-report niveau-féminisme-numerique
  report ifelse-value (Niveau-féminisme = "Faible") [0.1] [
    ifelse-value (Niveau-féminisme = "Moyen") [0.3] [
      ifelse-value (Niveau-féminisme = "Fort") [0.6] [0.0]
    ]
  ]
end
;; ... [Autres calculateurs d'impact]
;; ########################################
;; ### MISE À JOUR DES FACTEURS DYNAMIQUES
;; ########################################

to mettre-a-jour-facteurs
  ask turtles [

    ;; Mise à jour économique
    set revenu_epou max list revenu_epou 3000  ; Revenu minimum garanti
    set revenu_epouxe max list revenu_epouxe 3000

    ;; Mise à jour éducation
    if random 100 < 5 [  ; 5% de chance d'amélioration éducative
      set education_epou one-of ["Analphabétisme" "Éducation de base" "Enseignement supérieur"]
      set education_epouxe one-of ["Analphabétisme" "Éducation de base" "Enseignement supérieur"]
    ]

    ;; Mise à jour facteurs sociaux
    set facteurs_culturels random-float 1.0  ; Aléatoire entre 0 et 1
    set facteurs_individuels random-float 1.0

    ;; Mise à jour migration
    if Migration-active? [
      ifelse temps-absence > 0 [
        set temps-absence temps-absence - 1
      ][
        if (random 100 < 2) [  ; 2% de chance de migration
          set temps-absence random 50
        ]
      ]
    ]

    ;; Mise à jour autonomie féminine
    if (genre = "femme") [
      set autonomie-financiere (revenu_epouxe > Seuil-autonomie-femme)
    ]
  ]
end

;; ########################
;; ### VISUALISATION ###
;; ########################


to plot-statuts-matrimoniaux
  set-current-plot "Évolution des statuts"
  plot-pen-reset
  plot count turtles with [color = green] ; Mariés
  plot count turtles with [color = red]  ; Divorcés
  plot count turtles with [color = blue or color = pink] ; Célibataires
end

to plot-impact-facteurs
  set-current-plot "Impact des facteurs"
  plot-pen-reset
  plot (total-impact-violence / count turtles * 100)
  plot (total-impact-intrusion / count turtles * 100)
  ; ... [Même logique pour autres facteurs]
end

;; ################################
;; ### CALCUL DES IMPACTS ###
;; ################################

to calculer-impacts
  ask turtles [
    ;; Correction syntaxique avec parenthèses et structure NetLogo valide
    set impact-violence impact-violences

    ;; Conversion explicite en float pour éviter les erreurs de type
    set impact-intrusion impact-intrusions

    ;; Normalisation des valeurs réseaux sociaux entre 0 et 1
    set impact-reseaux impact-reseau
  ]
end
;; ##############################
;; ### ARRÊT DE LA SIMULATION ###
;; ##############################

to stop-simulation
  ;; Arrêter l'exécution
  set simulation-en-cours false

  ;; Afficher les statistiques finales
  output-print "=== SIMULATION ARRÊTÉE ==="
  output-print (word "Durée totale : " ticks " ticks")
  output-print (word "Taux final de divorce : " (precision taux-divorce 1) "%")

  ;; Réinitialiser les paramètres visuels
  ask turtles [ set color white ]
  output-print "Les agents ont été réinitialisés en blanc"
end
;; ################################
;; ### EXPORTATION DES DONNÉES ###
;; ################################

to collecter-donnees
  set taux-divorce (count turtles with [etat-matrimonial = "divorcé"] / count turtles) * 100
  set total-impact-violence sum [impact-violence] of turtles
  set total-impact-intrusion sum [impact-intrusion] of turtles
  set total-impact-reseaux sum [impact-reseaux] of turtles
  set total-impact-autonomie count turtles with [autonomie-financiere = true]
end

to export-data
  ; Ouvrir le fichier en mode écrasement
  file-open "divorce_data.csv"

  ; Écrire l'en-tête CSV
  file-print (word
    "ecart_revenu,"     ; Colonne 1
    "education_epou,"   ; Colonne 2
    "education_epouse," ; Colonne 3
    "residence,"        ; Colonne 4
    "religion_epou,"    ; Colonne 5
    "religion_epouse,"  ; Colonne 6
    "ecart_age,"        ; Colonne 7
    "facteurs_juridiques," ; Colonne 8
    "facteurs_culturels,"  ; Colonne 9
    "facteurs_individuels," ; Colonne 10
    "divorce"           ; Colonne 11
  )

  ; Parcourir tous les agents
  ask turtles [
    file-print (word
      (revenu_epouxe - revenu_epou) ","    ; Écart de revenu
      education_epou ","                   ; Éducation époux
      education_epouxe ","                 ; Éducation épouse
      residence ","                        ; Résidence
      religion_epou ","                    ; Religion époux
      religion_epouxe ","                  ; Religion épouse
      ecart_age ","                        ; Écart d'âge
      facteurs_juridiques ","              ; Facteurs juridiques
      facteurs_culturels ","               ; Facteurs culturels
      facteurs_individuels ","             ; Facteurs individuels
      ifelse-value (etat-matrimonial = "divorcé") [1] [0] ; Statut divorce
    )
  ]

  ; Fermer le fichier et confirmer
  file-close
  output-print "Données exportées dans divorce_data.csv"
end
@#$#@#$#@
GRAPHICS-WINDOW
384
3
892
512
-1
-1
15.152
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
173
12
236
45
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
239
12
302
45
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
174
50
303
83
NIL
stop-simulation
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
897
125
1293
321
Évolution des statuts matrimoniaux
Temps (ticks)
Nombre d'agents
0.0
1000.0
0.0
50.0
true
true
"" ""
PENS
"célibataire" 1.0 0 -13791810 true "" "plot count turtles with [etat-matrimonial = \"célibataire\"]"
"marié" 1.0 0 -10899396 true "" "plot count turtles with [etat-matrimonial = \"marié\"]"
"divorcé" 1.0 0 -2674135 true "" "plot count turtles with [etat-matrimonial = \"divorcé\"]"

INPUTBOX
11
10
165
83
nombre_agents
4.0
1
0
Number

SLIDER
4
109
176
142
Proba-violence
Proba-violence
0
100
89.0
1
1
%
HORIZONTAL

SLIDER
183
109
355
142
Intrusion-familiale
Intrusion-familiale
0
10
0.0
1
1
NIL
HORIZONTAL

SLIDER
1
148
199
181
Seuil-autonomie-femme
Seuil-autonomie-femme
0
10000
10000.0
100
1
DH
HORIZONTAL

SLIDER
204
148
376
181
facteurs_juridiques
facteurs_juridiques
0
100
0.0
1
1
%
HORIZONTAL

SLIDER
1
186
173
219
ecart_age
ecart_age
0
30
6.0
1
1
ans
HORIZONTAL

CHOOSER
178
184
316
229
Niveau-féminisme
Niveau-féminisme
"Faible" "Moyen" "Fort"
2

CHOOSER
2
224
179
269
Exposition-réseaux-sociaux
Exposition-réseaux-sociaux
"Bas" "Moyen" "Haut"
1

CHOOSER
183
234
364
279
education_epou
education_epou
"Analphabétisme" "Éducation de base" "Enseignement supérieur"
2

SWITCH
0
274
148
307
residence-switch
residence-switch
0
1
-1000

TEXTBOX
5
312
155
346
Urbain: On\nRural: Off
14
0.0
1

SWITCH
0
375
150
408
Migration-active?
Migration-active?
0
1
-1000

MONITOR
903
8
1024
53
Taux divorce actuel
taux-divorce
17
1
11

MONITOR
901
61
1001
106
Impact Violence
total-impact-violence
17
1
11

MONITOR
1013
62
1164
107
Impact Intrusion familiale
total-impact-intrusion
17
1
11

MONITOR
1175
10
1323
55
Impact Réseaux sociaux
total-impact-reseaux
17
1
11

MONITOR
1176
63
1297
108
Autonomie féminine
total-impact-autonomie
17
1
11

PLOT
911
336
1291
517
Impact relatif des facteurs
NIL
NIL
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"violence" 1.0 0 -2674135 true "" "plot count turtles with[violence-subie]"
"autonomie" 1.0 0 -11085214 true "" "plot count turtles with[autonomie-financiere]"
"l'économie" 1.0 0 -13791810 true "" "plot count turtles with[impact-economique]"

BUTTON
232
481
330
514
NIL
export-data
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
181
287
362
332
education_epouxe
education_epouxe
"Analphabétisme" "Éducation de base" "Enseignement supérieur"
0

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
