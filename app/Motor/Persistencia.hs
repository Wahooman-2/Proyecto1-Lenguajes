module Motor.Persistencia (guardarPartida, cargarPartida) where

import Motor.Tipos
import System.Directory (doesFileExist)
import Text.Read (readMaybe)
import Data.Map (Map)
import qualified Data.Map as Map

guardarPartida :: String -> Estado -> IO ()
guardarPartida archivo estado = do
    writeFile archivo (show estado)
    putStrLn $ "Partida guardada exitosamente en \"" ++ archivo ++ "\"."

cargarPartida :: Mundo -> String -> IO (Maybe Estado)
cargarPartida mundoActual archivo = do
    existe <- doesFileExist archivo
    if not existe then do
        putStrLn $ "Error: El archivo \"" ++ archivo ++ "\" no existe."
        return Nothing

    else do
        contenido <- readFile archivo
        case readMaybe contenido :: Maybe Estado of
            Nothing -> do
                putStrLn "Error: El archivo de partida esta corrupto o es invalido."
                return Nothing

            Just estadoCargado -> do
                let mundoGuardado = firmaMundo estadoCargado
                if mundoTitulo mundoGuardado /= mundoTitulo mundoActual then do
                    putStrLn "Error: Esta partida pertenece a un mundo distinto."
                    return Nothing

                else do
                    putStrLn $ "Partida cargada desde \"" ++ archivo ++ "\"."
                    return (Just estadoCargado)