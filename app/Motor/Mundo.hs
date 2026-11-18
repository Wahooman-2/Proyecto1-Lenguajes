-- Lectura del archivo de mundo
-- Convierte el texto del archivo en bloques de líneas numeradas, listos para
-- que el reconocedor los lea uno por uno
module Motor.Mundo
  ( leerMundo
  , Linea
  , Bloque
  , preprocesar
  , numerar
  , recortar
  , separarBloques
  ) where

import Motor.Tipos
import Motor.Reconocedor
import qualified Data.Map as Map

-- Una línea del archivo con su número original
-- El número se pone antes de descartar nada, así los errores apuntan a la
-- línea real aunque haya comentarios o líneas vacías antes
type Linea = (Int, String)

-- Las líneas que hay entre dos separadores
type Bloque = [Linea]

-- Texto del archivo -> bloques de líneas útiles
-- Quita espacios al inicio y al final, ignora líneas vacías y comentarios ---

preprocesar :: String -> [Bloque]
preprocesar = separarBloques . filter util . map limpiar . numerar . lines
  where
    limpiar (n, t) = (n, recortar t)
    util (_, t) = not (null t) && not (esComentario t)

-- Pone a cada línea su número, empezando en 1
numerar :: [String] -> [Linea]
numerar = desde 1
  where
    desde _ [] = []
    desde n (t : ts) = (n, t) : desde (n + 1) ts

-- Quita los espacios del inicio y del final. También quita tabuladores, el
-- \r que deja un archivo con fin de línea y la marca BOM que algunos
-- editores ponen al principio de un archivo UTF-8
recortar :: String -> String
recortar = invertir . dropWhile blanco . invertir . dropWhile blanco
  where
    blanco c = c `elem` " \t\r\xFEFF"

-- Una línea de comentario empieza con # 
esComentario :: String -> Bool
esComentario ('#' : _) = True
esComentario _ = False

-- Parte la lista de líneas en cada línea que solo contiene ---
-- Los bloques vacíos (dos separadores seguidos, o un separador al principio o
-- al final del archivo) se descartan.
separarBloques :: [Linea] -> [Bloque]
separarBloques = filter (not . null) . foldr paso [[]]
  where
    paso l (b : bs)
      | esSeparador l = [] : b : bs
      | otherwise = (l : b) : bs
    -- El acumulador nunca está vacío porque arranca en [[]], pero hace falta
    -- el caso para que la función sea total.
    paso _ [] = []

esSeparador :: Linea -> Bool
esSeparador (_, t) = t == "---"

-- Invertir una lista
invertir :: [a] -> [a]
invertir = foldl (\acc x -> x : acc) []

-- Un campo de un bloque: número de línea, clave y valor
type Campo = (Int, String, String)

-- La cabecera del archivo ya leída
data Cabecera = Cabecera
  { cabTitulo :: String
  , cabInicio :: IdSala
  , cabMeta   :: Meta
  , cabTurnos :: Int
  } deriving (Eq, Show)

-- Una sala tal como se lee del archivo, antes de validar. Las salidas quedan
-- en una lista y no en un Map para poder ver si hay dos salidas en la misma
-- dirección, cosa que un Map ya no deja ver
data SalaCruda = SalaCruda
  { crudaId      :: IdSala
  , crudaDesc    :: String
  , crudaSalidas :: [(Direccion, Salida)]
  , crudaObjetos :: [IdObjeto]
  } deriving (Eq, Show)

-- Lo que puede ser un bloque que no es la cabecera
data BloqueLeido = DeObjeto Objeto | DeSala SalaCruda
  deriving (Eq, Show)

-- Lee todos los bloques. Si hay algún error de sintaxis devuelve la lista
-- completa de errores, de todos los bloques. Si no devuelve la cabecera, los objetos y
-- las salas, en el orden del archivo
reconocer :: [Bloque] -> Either [ErrorMundo] (Cabecera, [Objeto], [SalaCruda])
reconocer [] = reconocer [[]]
reconocer (cab : resto) = case reconocerCabecera cab of
  Right c | null erroresBloques -> Right (c, objetos, salas)
          | otherwise -> Left erroresBloques
  Left es -> Left (es ++ erroresBloques)
  where
    rs = map reconocerBloque resto
    erroresBloques = juntar [es | Left es <- rs]
    objetos = [o | Right (DeObjeto o) <- rs]
    salas = [s | Right (DeSala s) <- rs]

-- Mira la primera línea del bloque para saber si es un OBJETO o una SALA
reconocerBloque :: Bloque -> Either [ErrorMundo] BloqueLeido
reconocerBloque [] = Left []
-- El caso vacío no ocurre ya que separarBloques descarta los bloques vacíos
reconocerBloque b@((n, t) : _) = case completo lineaClave t of
  Nothing -> Left [LineaMalFormada n t]
  Just ("OBJETO", _) -> fmap DeObjeto (reconocerObjeto b)
  Just ("SALA", _) -> fmap DeSala (reconocerSala b)
  Just (k, _) -> Left [BloqueDesconocido n k]

-- La cabecera lleva MUNDO, INICIO, META y TURNOS (cada uno exactamente una vez)
reconocerCabecera :: Bloque -> Either [ErrorMundo] Cabecera
reconocerCabecera b = case (mTitulo, mInicio, mMeta, mTurnos) of
  (Just t, Just i, Just m, Just k) | null errores ->
    Right (Cabecera t (IdSala i) m k)
  _ -> Left errores
  where
    inicio = primeraLinea b
    (cs, malas) = campos b
    (rTitulo, e1) = unico inicio "cabecera" "MUNDO" cs
    (rInicio, e2) = unico inicio "cabecera" "INICIO" cs
    (rMeta, e3) = unico inicio "cabecera" "META" cs
    (rTurnos, e4) = unico inicio "cabecera" "TURNOS" cs
    (mTitulo, e5) = convertir leerTexto rTitulo
    (mInicio, e6) = convertir leerId rInicio
    (mMeta, e7) = convertir leerMeta rMeta
    (mTurnos, e8) = convertir leerTurnos rTurnos
    errores = malas
      ++ desconocidas ["MUNDO", "INICIO", "META", "TURNOS"] cs
      ++ juntar [e1, e2, e3, e4, e5, e6, e7, e8]

-- Un bloque OBJETO lleva OBJETO y DESC (cada uno exactamente una vez)
reconocerObjeto :: Bloque -> Either [ErrorMundo] Objeto
reconocerObjeto b = case (mId, mDesc) of
  (Just i, Just d) | null errores -> Right (Objeto (IdObjeto i) d)
  _ -> Left errores
  where
    inicio = primeraLinea b
    (cs, malas) = campos b
    nombre = nombreBloque "objeto" "OBJETO" cs
    (rId, e1) = unico inicio nombre "OBJETO" cs
    (rDesc, e2) = unico inicio nombre "DESC" cs
    (mId, e3) = convertir leerId rId
    (mDesc, e4) = convertir leerTexto rDesc
    errores = malas
      ++ desconocidas ["OBJETO", "DESC"] cs
      ++ juntar [e1, e2, e3, e4]

-- Un bloque SALA lleva SALA y DESC una vez, y cero o más SALIDA y OBJETO
reconocerSala :: Bloque -> Either [ErrorMundo] SalaCruda
reconocerSala b = case (mId, mDesc) of
  (Just i, Just d) | null errores -> Right (SalaCruda (IdSala i) d salidas objetos)
  _ -> Left errores
  where
    inicio = primeraLinea b
    (cs, malas) = campos b
    nombre = nombreBloque "sala" "SALA" cs
    (rId, e1) = unico inicio nombre "SALA" cs
    (rDesc, e2) = unico inicio nombre "DESC" cs
    (mId, e3) = convertir leerId rId
    (mDesc, e4) = convertir leerTexto rDesc
    leidas = [leerSalida n v | (n, k, v) <- cs, k == "SALIDA"]
    salidas = [x | (_, Just x) <- leidas]
    e5 = juntar [es | (es, _) <- leidas]
    ids = [leerId (n, v) | (n, k, v) <- cs, k == "OBJETO"]
    objetos = [IdObjeto i | (Just i, _) <- ids]
    e6 = juntar [es | (_, es) <- ids]
    errores = malas
      ++ desconocidas ["SALA", "DESC", "SALIDA", "OBJETO"] cs
      ++ juntar [e1, e2, e3, e4, e5, e6]

-- La clave son letras mayúsculas, después de los dos
-- puntos puede haber espacios y el valor es todo lo que sigue
lineaClave :: ReadS (String, String)
lineaClave s =
  [((k, v), r4) | (k, r1) <- maximal (unoOMas (caracter (`elem` ['A' .. 'Z']))) s
                 , (_, r2) <- literal ":" r1
                 , (_, r3) <- espacios r2
                 , (v, r4) <- restoDeLinea r3]

-- Separa las líneas de un bloque en campos. Las líneas que no tienen la forma
-- CLAVE: valor no son campos y dan un error
campos :: Bloque -> ([Campo], [ErrorMundo])
campos [] = ([], [])
campos ((n, t) : ls) = case completo lineaClave t of
  Nothing -> (cs, LineaMalFormada n t : es)
  Just (k, v) -> ((n, k, v) : cs, es)
  where
    (cs, es) = campos ls

-- Busca un campo que debe aparecer exactamente una vez. Si falta da
-- CampoAusente (con la línea donde empieza el bloque). Si se repite da un
-- CampoRepetido por cada repetición de más y se queda con la primera
unico :: Int -> String -> String -> [Campo] -> (Maybe (Int, String), [ErrorMundo])
unico inicio bloque clave cs = case [ (n, v) | (n, k, v) <- cs, k == clave ] of
  [] -> (Nothing, [CampoAusente inicio bloque clave])
  (x : xs) -> (Just x, [ CampoRepetido n clave | (n, _) <- xs ])

-- Las claves que no están permitidas en este tipo de bloque
desconocidas :: [String] -> [Campo] -> [ErrorMundo]
desconocidas permitidas cs =
  [ClaveDesconocida n k | (n, k, _) <- cs, not (k `elem` permitidas)]

-- Cómo se llama el bloque en los mensajes, por ejemplo: sala 'plaza'
nombreBloque :: String -> String -> [Campo] -> String
nombreBloque tipo clave cs = case [ v | (_, k, v) <- cs, k == clave ] of
  (v : _) -> tipo ++ " '" ++ v ++ "'"
  [] -> tipo

-- Número de la primera línea del bloque
primeraLinea :: Bloque -> Int
primeraLinea ((n, _) : _) = n
primeraLinea [] = 1

juntar :: [[a]] -> [a]
juntar = foldr (++) []

-- Si el campo está lo convierte con f. Si no está no hay nada que convertir,
-- porque la falta ya se reportó en unico
convertir :: ((Int, String) -> (Maybe a, [ErrorMundo]))
          -> Maybe (Int, String) -> (Maybe a, [ErrorMundo])
convertir _ Nothing = (Nothing, [])
convertir f (Just x) = f x

leerTexto :: (Int, String) -> (Maybe String, [ErrorMundo])
leerTexto (_, v) = (Just v, [])

leerId :: (Int, String) -> (Maybe String, [ErrorMundo])
leerId (n, v) = case completo identificador v of
  Nothing -> (Nothing, [IdentificadorInvalido n v])
  Just i -> (Just i, [])

leerMeta :: (Int, String) -> (Maybe Meta, [ErrorMundo])
leerMeta (n, v) = case completo meta v of
  Nothing -> (Nothing, [MetaMalFormada n v])
  Just m -> (Just m, [])

-- TURNOS debe ser un entero positivo
leerTurnos :: (Int, String) -> (Maybe Int, [ErrorMundo])
leerTurnos (n, v) = case completo entero v of
  Nothing -> (Nothing, [TurnosNoNumerico n v])
  Just k | k > 0 -> (Just k, [])
         | otherwise -> (Nothing, [TurnosInvalidos k])

-- llegar a <sala>  o  llevar <objeto> a <sala>
meta :: ReadS Meta
meta = llegar <|> llevar
  where
    llegar s = [(LlegarA (IdSala sala), r5) | (_, r1) <- literal "llegar" s
                                       , (_, r2) <- espacios1 r1
                                       , (_, r3) <- literal "a" r2
                                       , (_, r4) <- espacios1 r3
                                       , (sala, r5) <- identificador r4]
    llevar s = [(LlevarA (IdObjeto obj) (IdSala sala), r7)  | (_, r1) <- literal "llevar" s
                                                            , (_, r2) <- espacios1 r1
                                                            , (obj, r3) <- identificador r2
                                                            , (_, r4) <- espacios1 r3
                                                            , (_, r5) <- literal "a" r4
                                                            , (_, r6) <- espacios1 r5
                                                            , (sala, r7) <- identificador r6]

-- Una palabra para la SALIDA: todo lo que no sea espacio, tabulador o guion.
palabra :: ReadS String
palabra = maximal (unoOMas (caracter (\c -> not (c `elem` " \t-"))))

-- La forma de una SALIDA, sin mirar todavía si la dirección y los
-- identificadores son válidos
salidaCruda :: ReadS (String, String, Maybe String)
salidaCruda s =[((d, t, req), r6) | (d, r1) <- palabra s
                                  , (_, r2) <- espacios r1
                                  , (_, r3) <- literal "->" r2
                                  , (_, r4) <- espacios r3
                                  , (t, r5) <- palabra r4
                                  , (req, r6) <- opcional requisito r5]
  where
    requisito r = [ (o, q4) | (_, q1) <- espacios1 r
                            , (_, q2) <- literal "requiere" q1
                            , (_, q3) <- espacios1 q2
                            , (o, q4) <- palabra q3 ]

-- Lee una SALIDA. Primero reconoce la forma y después revisa cada palabra así
-- se distingue una dirección inexistente de un identificador inválido
leerSalida :: Int -> String -> ([ErrorMundo], Maybe (Direccion, Salida))
leerSalida n v = case completo salidaCruda v of
  Nothing -> ([SalidaMalFormada n v], Nothing)
  Just x -> salidaDe n x

salidaDe :: Int -> (String, String, Maybe String)
         -> ([ErrorMundo], Maybe (Direccion, Salida))
salidaDe n (d, t, req) = (errores, valor)
  where
    errDireccion = case direccionDeNombre d of
      Nothing -> [DireccionInexistente n d]
      Just _ -> []
    errDestino = if esIdentificador t then [] else [IdentificadorInvalido n t]
    errRequisito = case req of
      Just o | not (esIdentificador o) -> [IdentificadorInvalido n o]
      _ -> []
    errores = errDireccion ++ errDestino ++ errRequisito
    valor = case direccionDeNombre d of
      Just dir | null errores ->
        Just (dir, Salida (IdSala t) (fmap IdObjeto req))
      _ -> Nothing

-- Lee el texto completo del archivo de mundo: preprocesa, reconoce y valida.
-- Es pura, es decir, si hay errores de sintaxis no se intenta validar lo demás
leerMundo :: String -> Either [ErrorMundo] Mundo
leerMundo texto = case reconocer (preprocesar texto) of
  Left es -> Left es
  Right (cab, objetos, salas) -> case validar cab objetos salas of
    [] -> Right (construir cab objetos salas)
    es -> Left es

-- Revisa las reglas V2 a V10 sobre lo que se leyó y devuelve todos los errores
-- juntos. Cada regla da un error por cada violación
-- Para no llenar de errores en cadena: V7 y V10 solo miran objetos que sí
-- están definidos (los que no, ya salen en V4, V6 o V8), y V9 solo se revisa si
-- INICIO existe
validar :: Cabecera -> [Objeto] -> [SalaCruda] -> [ErrorMundo]
validar cab objetos salas =
  juntar [v2, v3, v4, v5, v6, v7, v8, v9, v10]
  where
    idsSalas = map crudaId salas
    idsObjetos = map objetoId objetos
    colocaciones = [(o, crudaId s) | s <- salas, o <- crudaObjetos s]
    colocados = map fst colocaciones

    -- V2: ids repetidos
    v2 = [SalaDuplicada s | s <- duplicados idsSalas] ++ [ObjetoDuplicado o | o <- duplicados idsObjetos]

    -- V3: salida hacia una sala que no existe
    v3 = [SalidaASalaInexistente (crudaId s) d dest | s <- salas, (d, Salida dest _) <- crudaSalidas s
                                                                , not (dest `elem` idsSalas)]

    -- V4: salida que requiere un objeto que no existe
    v4 = [RequisitoInexistente (crudaId s) d o | s <- salas , (d, Salida _ (Just o)) <- crudaSalidas s
                                                            , not (o `elem` idsObjetos)]

    -- V5: dos salidas en la misma dirección
    v5 = [DireccionRepetida (crudaId s) d | s <- salas, d <- duplicados (map fst (crudaSalidas s))]

    -- V6: sala que contiene un objeto no definido
    v6 = [ObjetoNoDefinidoEnSala (crudaId s) o | s <- salas, o <- unicos (crudaObjetos s)
                                                           , not (o `elem` idsObjetos)]

    -- V7: objeto colocado más de una vez
    v7 = [ObjetoEnVariasSalas o [r | (o2, r) <- colocaciones, o2 == o]
         | o <- duplicados colocados
         , o `elem` idsObjetos]

    -- V8: INICIO o META con una sala o un objeto que no existe
    v8 = [InicioInexistente (cabInicio cab) | not (cabInicio cab `elem` idsSalas)]
      ++ errMeta
    errMeta = case cabMeta cab of
      LlegarA s -> [MetaSalaInexistente s | not (s `elem` idsSalas)]
      LlevarA o s -> [MetaObjetoInexistente o | not (o `elem` idsObjetos)]
                  ++ [MetaSalaInexistente s | not (s `elem` idsSalas)]

    -- V9: sala a la que no se llega desde INICIO (se ignoran los requisitos)
    v9 = if cabInicio cab `elem` idsSalas
           then [SalaInalcanzable r | r <- unicos idsSalas, not (r `elem` alcanzables salas (cabInicio cab))]
           else []

    -- V10: objeto que hace falta (para la meta o para cruzar una salida) pero
    -- no está colocado en ninguna sala
    necesarios = objetoDeMeta ++ [o | s <- salas, (_, Salida _ (Just o)) <- crudaSalidas s]
    objetoDeMeta = case cabMeta cab of
      LlevarA o _ -> [o]
      LlegarA _ -> []
    v10 = [ObjetoInconseguible o | o <- unicos necesarios, o `elem` idsObjetos, not (o `elem` colocados)]

-- Las salas a las que se puede llegar desde una sala de origen siguiendo las
-- salidas, sin mirar los requisitos. Va agregando las salas nuevas hasta que ya
-- no aparece ninguna
alcanzables :: [SalaCruda] -> IdSala -> [IdSala]
alcanzables salas origen = explorar [origen] [origen]
  where
    explorar [] vistos = vistos
    explorar (r : pendientes) vistos = explorar (pendientes ++ nuevas) (vistos ++ nuevas)
      where
        nuevas = unicos [d | d <- vecinas r, not (d `elem` vistos)]
    vecinas r = [dest | s <- salas, crudaId s == r, (_, Salida dest _) <- crudaSalidas s]

-- Cada elemento repetido, una sola vez
duplicados :: Eq a => [a] -> [a]
duplicados [] = []
duplicados (x : xs)
  | x `elem` xs = x : duplicados (filter (/= x) xs)
  | otherwise = duplicados xs

-- Los elementos sin repetir, en su orden de aparición
unicos :: Eq a => [a] -> [a]
unicos [] = []
unicos (x : xs) = x : unicos (filter (/= x) xs)

-- Arma el Mundo con lo ya validado. Aquí los ids no se repiten y no hay dos
-- salidas en la misma dirección, así que los Map no pierden nada
construir :: Cabecera -> [Objeto] -> [SalaCruda] -> Mundo
construir cab objetos salas = Mundo
  {mundoTitulo = cabTitulo cab
  , mundoInicio = cabInicio cab
  , mundoMeta = cabMeta cab
  , mundoTurnos = cabTurnos cab
  , mundoObjetos = Map.fromList [(objetoId o, o) | o <- objetos]
  , mundoSalas = Map.fromList [(crudaId s, aSala s) | s <- salas]}
  where
    aSala s = Sala (crudaId s) (crudaDesc s) (Map.fromList (crudaSalidas s)) (crudaObjetos s)


