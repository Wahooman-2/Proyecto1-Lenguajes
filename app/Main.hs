module Main where

import System.Environment (getArgs)
import System.Exit (exitFailure, exitSuccess)
import System.IO (hFlush, stdout, isEOF)
import Motor.Tipos
import Motor.Mundo (leerMundo)
import Motor.Comandos (leerComando)
import Motor.Nucleo (estadoInicial, ejecutar, evaluarEstado)
import Motor.Persistencia

-- Archivo que se encarga de la ejecucion del juego --

main :: IO ()
main = do
    args <- getArgs
    case args of
        ["-validar", archivo] -> validarMundo archivo
        [archivo] -> iniciarJuego archivo
        _ -> do
            putStrLn "Uso: aventura [-validar] <archivo_mundo>"
            exitFailure


-- Vaidacion de mundo --
validarMundo :: String -> IO ()
validarMundo archivo = do
    contenido <- readFile archivo
    case leerMundo contenido of
        Left errores -> do
            mapM_ (putStrLn . describirError) errores
            exitFailure

        Right _ -> do
            putStrLn "Mundo valido."
            exitSuccess

-- Funcion para iniciar el juego --
iniciarJuego :: String -> IO ()
iniciarJuego archivo = do
    contenido <- readFile archivo
    case leerMundo contenido of
        Left errores -> do
            mapM_ (putStrLn . describirError) errores
            exitFailure

        Right mundo -> do
            putStrLn("\n=== " ++ mundoTitulo mundo ++ " ===")
            let estadoBase = estadoInicial mundo
                (mensajes, _) = ejecutar Mirar estadoBase
            mapM_ putStrLn mensajes
            loopJuego mundo estadoBase

-- Funcion para seguir recibiendo comandos --
loopJuego :: Mundo -> Estado -> IO ()
loopJuego mundo estado = do
    putStr ("[Turnos restantes: " ++ show (turnosRestantes estado) ++ "] > ")
    hFlush stdout
    eof <- isEOF
    if eof then putStrLn "Fin de la entrada. Saliendo..."
    else do
        entrada <- getLine
        case leerComando entrada of
            Nothing -> do
                putStrLn "No entendi eso."
                loopJuego mundo estado

            Just comando -> do
                let (mensajes, newEstado) = ejecutar comando estado
                mapM_ putStrLn mensajes
                case comando of
                    Salir -> exitSuccess

                    Guardar archivo -> do
                        guardarPartida archivo newEstado
                        loopJuego mundo newEstado

                    Cargar archivo -> do
                        mEstado <- cargarPartida mundo archivo
                        case mEstado of
                            Nothing -> loopJuego mundo newEstado
                            Just estadoCargado -> do
                                let (mensajes, _) = ejecutar Mirar estadoCargado
                                mapM_ putStrLn mensajes
                                loopJuego mundo estadoCargado

                    _ -> case evaluarEstado mundo newEstado of
                            Ganar -> do
                                putStrLn "\n*** ¡Has ganado! ***"
                                exitSuccess

                            FinTurnos -> do
                                putStrLn "\n*** Se acabo el tiempo ***"
                                exitSuccess

                            Continuar ->
                                loopJuego mundo newEstado