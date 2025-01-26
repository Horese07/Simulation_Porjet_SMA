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

 
  violence-subie
  intrusion-famille
  reseaux-sociaux
  autonomie-financiere
  temps-absence
  revenu_epou
  revenu_epouxe
  religion_epou
  religion_epouxe

  impact-violence     
  impact-intrusion   
  impact-reseaux      


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

 
  set revenu_epou random 15000 + 3000
  set revenu_epouxe random 12000 + 3000
  set education_epou one-of ["Analphabétisme" "Éducation de base" "Enseignement supérieur"]
  set education_epouxe one-of ["Analphabétisme" "Éducation de base" "Enseignement supérieur"]

  
  set violence-subie (random-float 100 < Proba-violence)
  set intrusion-famille random-normal (Intrusion-familiale / 2) 0.5
 set reseaux-sociaux
  ifelse-value (Exposition-réseaux-sociaux = "Bas")
  [ 0.1 ]
  [ ifelse-value (Exposition-réseaux-sociaux = "Moyen")
    [ 0.3 ]
    [ ifelse-value (Exposition-réseaux-sociaux = "Haut")
      [ 0.6 ]
      [ 0 ]
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
 
  mettre-a-jour-facteurs  
  calculer-impacts        
  
  ask turtles [           
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


  if (genre = "femme" and autonomie-financiere) [
    ; 30% de chance de garde si la femme est autonome
    set has_child (random-float 1 < 0.3)
  ]

 
  if is-turtle? conjoint [
    ask conjoint [
      set color red
      set etat-matrimonial "divorcé"
      set experience-divorce true
      set conjoint nobody

     
      if (genre = "homme") [
        set has_child false
      ]
    ]
  ]


  set conjoint nobody

 
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

;; ########################################
;; ### MISE À JOUR DES FACTEURS DYNAMIQUES
;; ########################################

to mettre-a-jour-facteurs
  ask turtles [
   
    
    set revenu_epou max list revenu_epou 3000  
    set revenu_epouxe max list revenu_epouxe 3000

   
    if random 100 < 5 [ 
      set education_epou one-of ["Analphabétisme" "Éducation de base" "Enseignement supérieur"]
      set education_epouxe one-of ["Analphabétisme" "Éducation de base" "Enseignement supérieur"]
    ]

   
    set facteurs_culturels random-float 1.0  ; Aléatoire entre 0 et 1
    set facteurs_individuels random-float 1.0

  
    if Migration-active? [
      ifelse temps-absence > 0 [
        set temps-absence temps-absence - 1
      ][
        if (random 100 < 2) [  ; 2% de chance de migration
          set temps-absence random 50
        ]
      ]
    ]

   
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
  plot count turtles with [color = blue or color = pink]
end

to plot-impact-facteurs
  set-current-plot "Impact des facteurs"
  plot-pen-reset
  plot (total-impact-violence / count turtles * 100)
  plot (total-impact-intrusion / count turtles * 100)
  
end

;; ################################
;; ### CALCUL DES IMPACTS ###
;; ################################

to calculer-impacts
  ask turtles [
   
    set impact-violence impact-violences

   
    set impact-intrusion impact-intrusions

   
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
    "ecart_revenu,"     
    "education_epou,"   
    "education_epouse,"
    "residence,"        
    "religion_epou,"    
    "religion_epouse,"  
    "ecart_age,"        
    "facteurs_juridiques," 
    "facteurs_culturels,"  
    "facteurs_individuels," 
    "divorce"         
  )

  ; Parcourir tous les agents
  ask turtles [
    file-print (word
      (revenu_epouxe - revenu_epou) ","   
      education_epou ","                   
      education_epouxe ","                 
      residence ","                       
      religion_epou ","                   
      religion_epouxe ","                
      ecart_age ","                        
      facteurs_juridiques ","              
      facteurs_culturels ","              
      facteurs_individuels ","            
      ifelse-value (etat-matrimonial = "divorcé") [1] [0] ; Statut divorce
    )
  ]

  ; Fermer le fichier et confirmer
  file-close
  output-print "Données exportées dans divorce_data.csv"
end
