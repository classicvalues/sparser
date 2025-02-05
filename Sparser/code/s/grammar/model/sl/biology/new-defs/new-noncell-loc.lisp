(in-package :sparser)


(def-indiv-with-id bio-organ "PPS" "EFO:0003397" :name "hypopharyngeal sense organ")
(def-indiv-with-id bio-organ "cardiac mesoderm" "UBERON:0007005") 
(def-indiv-with-id bio-organ "cortical plate" "UBERON:0005343") 
(def-indiv-with-id bio-organ "ganglionic eminence" "UBERON:0004023")
(def-indiv-with-id bio-organ "hematopoietic system" "UBERON:0002390") 
(def-indiv-with-id bio-organ "hind paw" "UBERON:0002387") 
(def-indiv-with-id bio-organ "lamina propria" "UBERON:0000030") 
(def-indiv-with-id bio-organ "renin-angiotensin system" "UBERON:0018229") 
(def-indiv-with-id bio-organ "sex specific" "UBERON:0014402") 
(def-indiv-with-id bio-organ "stroma" "UBERON:0003891") 
(def-indiv-with-id bio-organ "subventricular zone" "UBERON:0004922") 
(def-indiv-with-id bio-organ "syncytium" "BTO:0005784" :name "syncytium" :plural ("syncytiums" "syncytia")) 
(def-indiv-with-id bio-organ "synovium" "EFO:0001393" :name "synovial membrane") 
(def-indiv-with-id bio-organ "tail vein" "UBERON:0003481") 
(def-indiv-with-id bio-organ "trabeculae" "EFO:0003706" :name "trabecular layer") 
(def-indiv-with-id secretion "follicular fluid" "UBERON:0000038") 
(def-indiv-with-id secretion "pancreatic secretion" "UBERON:0004795") 
(def-indiv-with-id secretion "pleural effusion" "UBERON:0000175") 
(def-indiv-with-id tissue "adipose tissue" "TS-0013") 
(def-indiv-with-id tissue "airway smooth muscle" "TS-0024") 
(def-indiv-with-id tissue "ascite" "TS-0058") 
(def-indiv-with-id tissue "cervical ganglia" "TS-0132") 
(def-indiv-with-id tissue "chorioallantoic membrane" "TS-0140") 
(def-indiv-with-id tissue "colonic epithelium" "TS-0163") 
(def-indiv-with-id tissue "corpus striatum" "TS-0183") 
(def-indiv-with-id tissue "dental pulp" "TS-0195") 
(def-indiv-with-id tissue "dorsal root ganglia" "TS-0954") 
(def-indiv-with-id tissue "embryonic ectoderm" "TS-0216") 
(def-indiv-with-id tissue "endothelium" "TS-0278") 
(def-indiv-with-id tissue "gastric corpus" "TS-0401") 
(def-indiv-with-id tissue "gastric mucosa" "TS-0404") 
(def-indiv-with-id tissue "granulation tissue" "UBERON:0010211") 
(def-indiv-with-id tissue "hair follicle" "TS-0432") 
(def-indiv-with-id tissue "head kidney" "TS-1206") 
(def-indiv-with-id tissue "mucosa associated lymphoid tissue" "UBERON:0001961") 
(def-indiv-with-id tissue "neural crest" "TS-0676") 
(def-indiv-with-id tissue "neural tissue" "UBERON:0003714") 
(def-indiv-with-id tissue "organ of Corti" "TS-0717") 
(def-indiv-with-id tissue "oviduct epithelium" "TS-1316") 
(def-indiv-with-id tissue "periodontal ligament" "TS-0763") 
(def-indiv-with-id tissue "peripheral blood" "TS-0771") 
(def-indiv-with-id tissue "umbilical vein" "TS-1082")

(def-indiv-with-id bio-organ "trophectoderm" "UBERON:0004345" :synonyms ("TE"))
(def-indiv-with-id bio-organ "inner cell mass" "UBERON:0000087" :synonyms ("ICM"))

(def-indiv-with-id tumor "HNet" "NCIT:C5783" :name "hepatic carcinoid tumor") 


(def-indiv-with-id bio-organ "capitellum" "EFO:0003398" :name "capitellum" :plural ("capitellums" "Capitella")) 
(def-indiv-with-id bio-organ "LDA" "EFO:0003613" :name "lateral dorsal aorta") 
(def-indiv-with-id bio-organ "PMBC" "EFO:0003697" :name "primordial midbrain channel") 
(def-indiv-with-id bio-organ "articular" "EFO:0003530" :name "anguloarticular") 
(def-indiv-with-id bio-organ "bronchiole" "EFO:0005097" :name "bronchiole") 
(def-indiv-with-id bio-organ "dels" "EFO:0000170" :name "DEL cells") 
(def-indiv-with-id bio-organ "amnioserosa" "BTO:0004800" :name "amnioserosa")
(def-indiv-with-id bio-organ "amnion" "MESH:D000650" :name "amniotic membrane" :synonyms ("AM")) ;note: "AM" is also a protein -- HMS also has this ambiguity
(def-indiv-with-id bio-organ "amastigote" "BTO:0000062" :name "amastigote") 
(def-indiv-with-id bio-organ "choanoflagellate" "BTO:0003434" :name "choanomastigote") 
(def-indiv-with-id bio-organ "epimastigote" "BTO:0000409" :name "epimastigote") 
(def-indiv-with-id bio-organ "mycelium" "BTO:0001436" :name "mycelium" :plural ("myceliums" "mycelia")) 

(def-indiv-with-id bio-organ "promastigote" "BTO:0001124" :name "promastigote") 
(def-indiv-with-id bio-organ "primordium" "BTO:0001886" :name "primordium" :plural ("primordiums" "primordia")) 
(def-indiv-with-id bio-organ "pregnant" "BTO:0004733" :name "gravid adult") 
(def-indiv-with-id bio-organ "tachyzoite" "BTO:0001346" :name "tachyzoite") 
(def-indiv-with-id bio-organ "trypomastigote" "BTO:0001398" :name "trypomastigote") 
(def-indiv-with-id bio-organ "trophozoite" "BTO:0001397" :name "trophozoite") 
(def-indiv-with-id bio-organ "pav" "EFO:0003701" :name "parachordal vessel") 
(def-indiv-with-id bio-organ "LLG" "EFO:0003493" :name "lateral line ganglion") 
(def-indiv-with-id bio-organ "conceptus" "BTO:0003834" :name "conceptus") 
(def-indiv-with-id bio-organ "merozoite" "BTO:0002272" :name "merozoite") 
(def-indiv-with-id bio-organ "signet-ring" "BTO:0001893" :name "ring stage") 
(def-indiv-with-id bio-organ "sporozoite" "BTO:0001292" :name "sporozoite") 
(def-indiv-with-id bio-organ "nephron" "MESH:D009399")

;;; post covid


(def-indiv-with-id bio-organ "globus pallidus" "UBERON:0001875" :name "Globus Pallidus")
(def-indiv-with-id bio-organ "GPe" "UBERON:0002476" :name "lateral globus pallidus" :synonyms ("globus pallidus external" "external globus pallidus") :maintain-case t)
(def-indiv-with-id bio-organ "GPi" "UBERON:0002477" :name "medial globus pallidus" :synonyms ("globus pallidus internal" "internal globus pallidus") :maintain-case t)
(def-indiv-with-id bio-organ "SNr" "UBERON:0001966" :name "substantia nigra pars reticulata" :maintain-case t)
(def-indiv-with-id bio-organ "bradyzoite" "BTO:0002342" :name "bradyzoite") 
(def-indiv-with-id bio-organ "gravid" "BTO:0004733" :name "gravid adult") 
(def-indiv-with-id bio-organ "metacestode" "BTO:0000859" :name "metacestode") 
(def-indiv-with-id bio-organ "schizont" "BTO:0001002" :name "schizont") 



(def-indiv-with-id bio-organ "trichome" "BTO:0001395")
(def-indiv-with-id bio-organ "CORM" "BTO:0000285" :name "corm") 

(def-indiv-with-id bio-organ "conidium" "BTO:0000283" :name "conidium") 
(def-indiv-with-id bio-organ "ascospore" "BTO:0000097" :name "ascospore") 
(def-indiv-with-id bio-organ "ookinete" "BTO:0004857" :name "ookinete") 
(def-indiv-with-id bio-organ "gametophyte" "BTO:0000495" :name "gametophyte") 
(def-indiv-with-id bio-organ "cercaria" "BTO:0005513" :name "cercaria") 
(def-indiv-with-id bio-organ "schistosomulum" "BTO:0002743" :name "schistosomulum") 
(def-indiv-with-id bio-organ "sporocyst" "BTO:0005891" :name "sporocyst") 
(def-indiv-with-id bio-organ "urediniospore" "BTO:0001417" :name "uredospore") 
(def-indiv-with-id bio-organ "metacercaria" "BTO:0003927" :name "metacercaria") 
(def-indiv-with-id bio-organ "sclerotium" "BTO:0001810" :name "sclerotium") 
(def-indiv-with-id bio-organ "endospore" "BTO:0002779" :name "endospore") 
(def-indiv-with-id bio-organ "cercaria" "BTO:0005513" :name "cercaria" :plural ("cercarias" "cercariae")) 
(def-indiv-with-id bio-organ "kinetoplastid" "BTO:0002502" :name "kinetoplastid") 
(def-indiv-with-id bio-organ "Cestode" "BTO:0005278" :name "cestode") 
(def-indiv-with-id bio-organ "sporozoa" "BTO:0000749" :name "sporozoan form") 
(def-indiv-with-id bio-organ "Cysticercus" "BTO:0003168" :name "cysticercus") 
