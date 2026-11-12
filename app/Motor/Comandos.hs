module Motor.Comandos where

import Data.Char (toLower)
import Motor.Tipos

filler :: [String]
filler = ["el", "la", "los", "las", "un", "una", "unos", "unas", "al", "a"]

leerComando :: String -> Maybe Comando
leerComando cmd = 
    let 
        lowerCmd = map toLower cmd
        wordsCmd = words lowerCmd
        cleanCmd = filter (`notElem` filler) wordsCmd
    in
    case cleanCmd of
        ["ir", txt] -> 
            case direccionDeNombre txt of
                Just d -> Just (Ir d)
                Nothing -> Nothing
        
        ["mirar"] -> Just Mirar
        ["ver"] -> Just Mirar -- Sinonimo --
        ["ayuda"] -> Just Ayuda
        ["salir"] -> Just Salir
        ["inventario"] -> Just Inventario
        ["inv"] -> Just Inventario -- Sinonimo --

        ["tomar", txt] -> Just (Tomar (IdObjeto txt))
        ["coger", txt] -> Just (Tomar (IdObjeto txt)) -- Sinonimo --
        ["agarrar", txt] -> Just (Tomar (IdObjeto txt)) -- Sinonimo --
        ["recoger", txt] -> Just (Tomar (IdObjeto txt)) -- Sinonimo --
        ["soltar", txt] -> Just (Soltar (IdObjeto txt))
        ["botar", txt] -> Just (Soltar (IdObjeto txt)) -- Sinonimo --
        ["examinar", txt] -> Just (Examinar (IdObjeto txt))
        ["revisar", txt] -> Just (Examinar (IdObjeto txt)) -- Sinonimo --

        ["guardar", txt] -> Just (Guardar txt)
        ["guardar"] -> Just (Guardar "guardado.txt") -- Default --
        ["cargar", txt] -> Just (Cargar txt)
        ["cargar"] -> Just (Cargar "guardado.txt") -- Default --

        _ -> Nothing
