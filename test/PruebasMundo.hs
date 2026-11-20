-- Pruebas de la lectura del mundo: leerMundo, el preprocesado y las piezas del
-- reconocedor. Los casos que leen archivos suponen que las pruebas corren desde
-- la carpeta raíz del proyecto 
{-# LANGUAGE OverloadedStrings #-}
module Main where

import Test.Hspec
import Motor.Tipos
import Motor.Reconocedor
import Motor.Mundo
import Motor.Comandos (leerComando)
import Motor.Nucleo (ejecutar)
import qualified Data.Map as Map

esValido :: Either [ErrorMundo] Mundo -> Bool
esValido (Right _) = True
esValido (Left _) = False

erroresDe :: Either [ErrorMundo] Mundo -> [ErrorMundo]
erroresDe (Left es) = es
erroresDe (Right _) = []

cantidadErrores :: Either [ErrorMundo] Mundo -> Int
cantidadErrores = length . erroresDe

empiezaConError :: String -> Bool
empiezaConError ('E' : 'r' : 'r' : 'o' : 'r' : ':' : ' ' : _) = True
empiezaConError _ = False

mensajesBien :: Either [ErrorMundo] Mundo -> Bool
mensajesBien r = null [m | m <- map describirError (erroresDe r), not (empiezaConError m) || '\n' `elem` m]

cabecera :: String -> [String]
cabecera turnos =
  ["MUNDO: Mínimo", "INICIO: a", "META: llegar a b", "TURNOS: " ++ turnos]

salasMinimas :: [String]
salasMinimas =
  ["---", "SALA: a", "DESC: Sala a.", "SALIDA: norte -> b", "---", "SALA: b", "DESC: Sala b.", "SALIDA: sur -> a"]

minimo :: String
minimo = unlines (cabecera "5" ++ salasMinimas)

minimoConTurnosCero :: String
minimoConTurnosCero = unlines (cabecera "0" ++ salasMinimas)

minimoWindows :: String
minimoWindows = unlines (map (++ "\r") (cabecera "5" ++ salasMinimas))

dosNorte :: String
dosNorte = unlines (cabecera "5"
  ++ [ "---", "SALA: a", "DESC: Sala a."
     , "SALIDA: norte -> b", "SALIDA: norte -> b"
     , "---", "SALA: b", "DESC: Sala b." ])

conComentarios :: String
conComentarios = unlines
  ["# comentario", "", "MUNDO: M", "TURNOS: x", "INICIO: a", "META: llegar a a", "---", "SALA: a", "DESC: A"]

mundoMock :: Mundo
mundoMock = Mundo
  { mundoTitulo = "Test"
  , mundoInicio = IdSala "sala1"
  , mundoMeta = LlegarA (IdSala "sala2")
  , mundoTurnos = 10
  , mundoObjetos = Map.fromList [(IdObjeto "llave", Objeto (IdObjeto "llave") "Una llave dorada")]
  , mundoSalas = Map.fromList
      [ (IdSala "sala1", Sala (IdSala "sala1") "Sala 1" (Map.singleton Norte (Salida (IdSala "sala2") Nothing)) [IdObjeto "llave"])
      , (IdSala "sala2", Sala (IdSala "sala2") "Sala 2" Map.empty [])
      ]
  }

estadoMock :: Estado
estadoMock = Estado
  { firmaMundo = mundoMock
  , salaActual = IdSala "sala1"
  , inventario = []
  , objetosSala = Map.fromList [(IdSala "sala1", [IdObjeto "llave"]), (IdSala "sala2", [])]
  , turnosRestantes = 10
  }

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  -- Carga de archivos de tu compañero
  ejemplo <- runIO (readFile "mundos/entrega.txt")
  propio <- runIO (readFile "mundos/mundo.txt")
  semantica <- runIO (readFile "mundos/invalido_semantica.txt")
  sintaxis <- runIO (readFile "mundos/invalido_sintaxis.txt")
  invSintaxis <- runIO (readFile "mundos/invalidos/sintaxis_v1.txt")
  invReferencias <- runIO (readFile "mundos/invalidos/referencias_v2_v5.txt")
  invObjetos <- runIO (readFile "mundos/invalidos/objetos_v6_v10.txt")
  invTurnosCero <- runIO (readFile "mundos/invalidos/turnos_cero.txt")

  describe "Motor.Mundo.leerMundo (Archivos del profesor)" $ do
    it "acepta el mundo de ejemplo" $
      esValido (leerMundo ejemplo) `shouldBe` True
    it "invalido_semantica da 9 errores" $
      cantidadErrores (leerMundo semantica) `shouldBe` 9
    it "invalido_sintaxis da errores" $
      cantidadErrores (leerMundo sintaxis) `shouldSatisfy` (> 0)
    it "los mensajes empiezan con Error: y van en su línea" $
      (mensajesBien (leerMundo semantica) && mensajesBien (leerMundo sintaxis)) `shouldBe` True

  describe "Motor.Mundo.leerMundo (Mundo propio)" $ do
    it "es válido" $
      esValido (leerMundo propio) `shouldBe` True
    it "tiene 9 salas" $
      fmap (length . mundoSalas) (leerMundo propio) `shouldBe` Right 9
    it "tiene 9 objetos" $
      fmap (length . mundoObjetos) (leerMundo propio) `shouldBe` Right 9
    it "da 16 turnos" $
      fmap mundoTurnos (leerMundo propio) `shouldBe` Right 16

  describe "Motor.Mundo.leerMundo (Mundos inválidos propios)" $ do
    it "sintaxis_v1 da 5 errores" $
      cantidadErrores (leerMundo invSintaxis) `shouldBe` 5
    it "referencias_v2_v5 da 6 errores" $
      cantidadErrores (leerMundo invReferencias) `shouldBe` 6
    it "objetos_v6_v10 da 5 errores" $
      cantidadErrores (leerMundo invObjetos) `shouldBe` 5
    it "turnos_cero da TurnosInvalidos" $
      leerMundo invTurnosCero `shouldBe` Left [TurnosInvalidos 0]

  describe "Motor.Mundo.leerMundo (Casos raros de formato)" $ do
    it "un archivo vacío da tres campos ausentes" $
      leerMundo "" `shouldBe` Left [CampoAusente 1 "cabecera" k | k <- ["MUNDO", "INICIO", "META"]]
    it "acepta el mundo mínimo" $
      esValido (leerMundo minimo) `shouldBe` True
    it "acepta fin de línea de Windows" $
      esValido (leerMundo minimoWindows) `shouldBe` True
    it "acepta la marca BOM al principio" $
      esValido (leerMundo ('\xFEFF' : minimo)) `shouldBe` True
    it "TURNOS 0 da TurnosInvalidos" $
      leerMundo minimoConTurnosCero `shouldBe` Left [TurnosInvalidos 0]
    it "dos salidas al norte dan DireccionRepetida" $
      leerMundo dosNorte `shouldBe` Left [DireccionRepetida (IdSala "a") Norte]
    it "el número de línea ignora comentarios y líneas vacías" $
      leerMundo conComentarios `shouldBe` Left [TurnosNoNumerico 4 "x"]

  describe "Motor.Reconocedor (Preprocesar y componentes)" $ do
    it "preprocesar numera y separa bloques" $
      preprocesar "A: 1\n# x\n\nB: 2\n---\nC: 3\n" `shouldBe` [[(1, "A: 1"), (4, "B: 2")], [(6, "C: 3")]]
    it "recortar quita espacios, tabuladores y \\r" $
      recortar "  hola \t\r" `shouldBe` "hola"
    it "esIdentificador acepta ñ y _ y rechaza mayúsculas y espacios" $
      map esIdentificador ["ñandú_2", "Sala", "a b", ""] `shouldBe` [True, False, False, False]
    it "direccionDeNombre reconoce direcciones" $
      (direccionDeNombre "oeste", direccionDeNombre "diagonal") `shouldBe` (Just Oeste, Nothing)
    it "entero lee positivos y negativos" $
      map (completo entero) ["12", "-12", "12a"] `shouldBe` [Just 12, Just (-12), Nothing]
    it "identificador lee la palabra completa" $
      map (completo identificador) ["a_b", "a b"] `shouldBe` [Just "a_b", Nothing]

  describe "Motor.Comandos.leerComando" $ do
    it "Reconoce el comando direccional explícito 'ir norte'" $
      leerComando "ir norte" `shouldBe` Just (Ir Norte)
    it "Reconoce la dirección abreviada 'norte'" $
      leerComando "norte" `shouldBe` Just (Ir Norte)
    it "Reconoce comandos de interacción con identificadores 'tomar llave'" $
      leerComando "tomar llave" `shouldBe` Just (Tomar (IdObjeto "llave"))
    it "Reconoce alias de un solo carácter/palabra como 'inv'" $
      leerComando "inv" `shouldBe` Just Inventario
    it "Rechaza entradas de texto sin sentido devolviendo Nothing" $
      leerComando "bailar macarena" `shouldBe` Nothing

  describe "Motor.Nucleo.ejecutar" $ do
    it "Mirar mantiene al jugador en la misma sala actual" $ do
      let (_, estNuevo) = ejecutar Mirar estadoMock
      salaActual estNuevo `shouldBe` IdSala "sala1"
    it "Ir hacia una dirección sin salida no altera la sala actual" $ do
      let (_, estNuevo) = ejecutar (Ir Sur) estadoMock
      salaActual estNuevo `shouldBe` IdSala "sala1"
    it "Ir hacia una dirección válida actualiza la sala actual" $ do
      let (_, estNuevo) = ejecutar (Ir Norte) estadoMock
      salaActual estNuevo `shouldBe` IdSala "sala2"
    it "Tomar un objeto válido lo agrega al inventario del jugador" $ do
      let (_, estNuevo) = ejecutar (Tomar (IdObjeto "llave")) estadoMock
      inventario estNuevo `shouldBe` [IdObjeto "llave"]
    it "Soltar un objeto del inventario lo transfiere de vuelta a la sala actual" $ do
      let estadoConLlave = estadoMock { inventario = [IdObjeto "llave"], objetosSala = Map.fromList [(IdSala "sala1", [])] }
      let (_, estNuevo) = ejecutar (Soltar (IdObjeto "llave")) estadoConLlave
      inventario estNuevo `shouldBe` []
      Map.lookup (IdSala "sala1") (objetosSala estNuevo) `shouldBe` Just [IdObjeto "llave"]