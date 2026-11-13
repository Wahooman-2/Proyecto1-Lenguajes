-- Combinadores de reconocimiento 

module Motor.Reconocedor
  ( -- Piezas básicas
    caracter
  , literal
  , vacio
  , (<|>)
  , alternativas
    -- Repeticiones
  , muchos
  , unoOMas
  , opcional
    -- Quedarse con una sola lectura
  , maximal
    -- Piezas para el formato del mundo
  , espacios
  , espacios1
  , entero
  , identificador
  , restoDeLinea
    -- Fin de la entrada
  , fin
  , completo
  ) where

import Motor.Tipos (esIdentificador)

-- Piezas básicas

-- Un carácter que cumpla el predicado
caracter :: (Char -> Bool) -> ReadS Char
caracter p (c:cs) | p c = [(c, cs)]
caracter _ _ = []

-- Exactamente este texto
literal :: String -> ReadS String
literal [] s = [([], s)]
literal (c:cs) s =
  [ (c : xs, r2) | (_, r1)  <- caracter (== c) s, (xs, r2) <- literal cs r1 ]

-- El reconocedor que nunca lee nada
vacio :: ReadS a
vacio _ = []

-- Las lecturas de @p@ y también las de @q@
(<|>) :: ReadS a -> ReadS a -> ReadS a
(p <|> q) s = p s ++ q s

-- Prueba todos los reconocedores de la lista
alternativas :: [ReadS a] -> ReadS a
alternativas = foldr (<|>) vacio

-- Repeticiones

-- Cero o más repeticiones. Devuelve todas las lecturas

muchos :: ReadS a -> ReadS [a]
muchos p = uno <|> ninguno
  where
    ninguno s = [([], s)]
    uno s = [ (x : xs, r2) | (x, r1)  <- p s, (xs, r2) <- muchos p r1 ]

-- Una o más repeticiones
unoOMas :: ReadS a -> ReadS [a]
unoOMas p s =  [ (x : xs, r2) | (x, r1)  <- p s, (xs, r2) <- muchos p r1 ]

-- Algo que puede estar o no. Da primero la lectura con valor y después la
-- que no lee nada
opcional :: ReadS a -> ReadS (Maybe a)
opcional p = conValor <|> sinNada
  where
    conValor s = [ (Just x, r) | (x, r) <- p s ]
    sinNada s  = [(Nothing, s)]

-- Ambigüedad

-- Se queda solo con la primera lectura. Con 'muchos' y 'unoOMas' la primera
-- es la más larga, así que esto lee "lo más posible" y evita que una palabra
-- se parta en pedazos
maximal :: ReadS a -> ReadS a
maximal p s = case p s of
  []      -> []
  (r : _) -> [r]

-- Piezas para el formato del mundo

-- Espacios y tabuladores, cero o más
espacios :: ReadS String
espacios = maximal (muchos (caracter (`elem` " \t")))

-- Espacios y tabuladores, uno o más
espacios1 :: ReadS String
espacios1 = maximal (unoOMas (caracter (`elem` " \t")))

-- Un entero (con signo menos opcional) 

-- 'read' es parcial, pero aquí nunca falla: solo se le pasa una cadena de
-- dígitos no vacía. Un número de muchísimos dígitos se desborda sin avisar
-- (para TURNOS no importa)
entero :: ReadS Int
entero = positivo <|> negativo
  where
    digitos = maximal (unoOMas (caracter (`elem` "0123456789")))
    positivo s = [ (read ds, r) | (ds, r) <- digitos s ]
    negativo s = [ (negate (read ds), r2) | (_, r1)  <- caracter (== '-') s 
                                          , (ds, r2) <- digitos r1 ]

-- Un identificador: la tira más larga de caracteres válidos
identificador :: ReadS String
identificador = maximal (unoOMas (caracter esCaracterId))
  where
    esCaracterId c = esIdentificador [c]

-- Todo lo que queda, sin mirarlo
restoDeLinea :: ReadS String
restoDeLinea s = [(s, "")]

-- Fin de la entrada

-- Solo tiene éxito si no queda nada por leer
fin :: ReadS ()
fin "" = [((), "")]
fin _  = []

-- Reconoce la cadena completa: devuelve la primera lectura que no deja
-- sobrante, o 'Nothing' si no hay ninguna. Esta es la función que usará
-- Motor.Mundo para convertir una línea en un valor o en un error.
completo :: ReadS a -> String -> Maybe a
completo p s = case [ x | (x, r1) <- p s, _ <- fin r1 ] of
  []      -> Nothing
  (x : _) -> Just x
