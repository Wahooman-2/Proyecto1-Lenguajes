module Motor.Nucleo where

    import Motor.Tipos
    import Data.List
    import qualified Data.Map as Map

    ejecutar :: Comando->  Mundo -> Estado -> ([String], Estado)
    ejecutar comando mundo estado = case comando of

        Salir -> (["Hasta pronto! Saliendo..."], estado)
        Ayuda -> (["Puedes usar: ir <direccion>, mirar, tomar <objeto>, soltar <objeto>, examinar <objeto>, inventario, guardar <achivo>, cargar <archivo>, ayuda, salir"], estado)

        Inventario -> let inv = inventario estado
                            msg = if null inv then "No llevas nada."
                            else "" ++ intercalate ", " [o | IdObjeto o <- inv]
                        in ([msg], estado)

        Ir direccion -> (["Aun nada lol"], estado)
        Mirar -> (["Aun nada lol"], estado)
        Tomar idObj -> (["Aun nada lol"], estado)
        Soltar isObj -> (["Aun nada lol"], estado)
        Examinar idObj -> (["Aun nada lol"], estado)
        Guardar file -> (["Guardando en " ++ file], estado)
        Cargar file -> (["Cargando desde " ++ file], estado)


         _ -> (["No entendí eso, intetna de nuevo, recuerda usar ayuda para ver que puedes hacer"], estado)
