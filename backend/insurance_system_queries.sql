
-- Table Client
CREATE TABLE Client (
  client_id SERIAL PRIMARY KEY,
  nom VARCHAR(100),
  prenom VARCHAR(100),
  date_naissance DATE,
  adresse VARCHAR(255)
);

-- Table Contrat
CREATE TABLE Contrat (
  contrat_id SERIAL PRIMARY KEY,
  type_contrat ENUM('Vie', 'Non Vie'),
  date_souscription DATE,
  montant_assure DECIMAL(15, 2),
  duree INT,
  client_id INT REFERENCES Client(client_id)
);

-- Table Sinistre
CREATE TABLE Sinistre (
  sinistre_id SERIAL PRIMARY KEY,
  date_declaration DATE,
  montant_indemnise DECIMAL(15, 2),
  contrat_id INT REFERENCES Contrat(contrat_id)
);

-- Table HistoriqueContrat
CREATE TABLE HistoriqueContrat (
  historique_id SERIAL PRIMARY KEY,
  date_modification DATE,
  description_modifications TEXT,
  contrat_id INT REFERENCES Contrat(contrat_id)
);

-- Table Role
CREATE TABLE Role (
  role_id SERIAL PRIMARY KEY,
  nom_role ENUM('Administrateur', 'Agent', 'Consultant')
);

-- Table Utilisateur
CREATE TABLE Utilisateur (
  utilisateur_id SERIAL PRIMARY KEY,
  username VARCHAR(100) UNIQUE NOT NULL,
  mot_de_passe VARCHAR(255) NOT NULL, -- Hash du mot de passe
  role_id INT REFERENCES Role(role_id)
);



-- Trigger for Client: Check for duplicate clients
CREATE OR REPLACE FUNCTION check_duplicate_client()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM Client
    WHERE nom = NEW.nom
    AND prenom = NEW.prenom
    AND date_naissance = NEW.date_naissance
  ) THEN
    RAISE EXCEPTION 'Client already exists with the same name and birth date.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_duplicate_client
BEFORE INSERT ON Client
FOR EACH ROW EXECUTE FUNCTION check_duplicate_client();

-- Trigger for Contrat: Ensure valid contract and log changes
CREATE OR REPLACE FUNCTION check_contrat_constraints()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.montant_assure <= 0 THEN
    RAISE EXCEPTION 'Montant assuré doit être supérieur à 0.';
  END IF;
  
  IF NEW.duree <= 0 THEN
    RAISE EXCEPTION 'Durée du contrat doit être positive.';
  END IF;

  INSERT INTO HistoriqueContrat (date_modification, description_modifications, contrat_id)
  VALUES (CURRENT_DATE, 'Nouveau contrat créé', NEW.contrat_id);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_contrat_constraints
BEFORE INSERT ON Contrat
FOR EACH ROW EXECUTE FUNCTION check_contrat_constraints();

-- Trigger for Sinistre: Ensure valid claims
CREATE OR REPLACE FUNCTION check_sinistre_constraints()
RETURNS TRIGGER AS $$
DECLARE
  insured_amount DECIMAL;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM Contrat WHERE contrat_id = NEW.contrat_id) THEN
    RAISE EXCEPTION 'Le sinistre doit être lié à un contrat valide.';
  END IF;

  IF NEW.date_declaration > (CURRENT_DATE + INTERVAL '30 days') THEN
    RAISE EXCEPTION 'Le sinistre doit être déclaré dans les 30 jours suivant l''incident.';
  END IF;

  SELECT montant_assure INTO insured_amount FROM Contrat WHERE contrat_id = NEW.contrat_id;
  IF NEW.montant_indemnise > insured_amount THEN
    RAISE EXCEPTION 'Le montant de l''indemnisation ne peut pas dépasser le montant assuré.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_sinistre_constraints
BEFORE INSERT ON Sinistre
FOR EACH ROW EXECUTE FUNCTION check_sinistre_constraints();

-- Trigger for Utilisateur: Ensure valid role and unique username
CREATE OR REPLACE FUNCTION check_role_and_username()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM Utilisateur WHERE username = NEW.username) THEN
    RAISE EXCEPTION 'Le nom d''utilisateur existe déjà.';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM Role WHERE role_id = NEW.role_id) THEN
    RAISE EXCEPTION 'Rôle invalide.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_role_and_username
BEFORE INSERT ON Utilisateur
FOR EACH ROW EXECUTE FUNCTION check_role_and_username();
