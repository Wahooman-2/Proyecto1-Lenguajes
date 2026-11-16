-- Lectura del archivo de mundo
-- Convierte el texto del archivo en bloques de líneas numeradas, listos para
-- que el reconocedor los lea uno por uno
module Motor.Mundo
  ( Linea
  , Bloque
  , preprocesar
  , numerar
  , recortar
  , separarBloques
  ) where

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
