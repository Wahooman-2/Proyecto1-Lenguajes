-- Tipos del dominio del motor de aventuras.

module Motor.Tipos
  ( -- Identificadores
    IdSala (..)      
  , IdObjeto (..)   
    -- Direcciones
  , Direccion (..)
  , todasLasDirecciones
  , nombreDireccion
  , direccionDeNombre
  , esIdentificador
    -- El mundo
  , Objeto (..)
  , Salida (..)
  , Sala (..)
  , Meta (..)
  , Mundo (..)
  , buscarSala
  , buscarObjeto
  , salidaEn
    -- Errores de lectura y validación
  , ErrorMundo (..)
  , describirError
    -- Juego en marcha
  , Comando (..)
  , Fin (..)
  , Estado (..)
  ) where


import Data.Map (Map)
import qualified Data.Map as Map

-- Identificadores

-- Identificador de sala. Es un newtype distinto del de objeto para que el
-- compilador no deje mezclarlos ya que las salas y los objetos tienen espacios de
-- nombres separados

-- El tipo NO garantiza que el texto sea un identificador válido eso lo comprueba 
-- el reconocedor al leer el archivo
newtype IdSala = IdSala String
  deriving (Eq, Ord, Show, Read)  

-- Identificador de objeto
newtype IdObjeto = IdObjeto String
  deriving (Eq, Ord, Show, Read)  

-- Direcciones

data Direccion = Norte | Sur | Este | Oeste | Arriba | Abajo
  deriving (Eq, Ord, Show, Read)  

-- Las seis direcciones, en el orden de la declaración
todasLasDirecciones :: [Direccion]
todasLasDirecciones = [Norte, Sur, Este, Oeste, Arriba, Abajo]

-- Cómo se escribe la dirección en el archivo y en los comandos
nombreDireccion :: Direccion -> String
nombreDireccion Norte  = "norte"
nombreDireccion Sur    = "sur"
nombreDireccion Este   = "este"
nombreDireccion Oeste  = "oeste"
nombreDireccion Arriba = "arriba"
nombreDireccion Abajo  = "abajo"

-- Inverso de nombreDireccion. Devuelve 'Nothing' si el texto no es una
-- dirección (no distingue mayúsculas)
direccionDeNombre :: String -> Maybe Direccion
direccionDeNombre txt = lookup txt [(nombreDireccion d, d) | d <- todasLasDirecciones]

-- Verifica si es un identificador válido de sala u objeto
esIdentificador :: String -> Bool
esIdentificador txt = not (null txt) && null (filter (not . valido) txt)
  where
    valido c = c `elem` ['a' .. 'z'] || c `elem` "áéíóúñü"
            || c `elem` ['0' .. '9'] || c == '_'
