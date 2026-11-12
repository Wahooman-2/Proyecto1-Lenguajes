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

        Ir direccion ->
            let idSalaAct = salaActual estado
            inv = inventario estado

            in case buscarSala isSalaAct mundo of
                Nothing -> (["Error de codigo: Escapaste el mundo! Estas en una sala que no existe."], estado)
                Just sala ->
                    case salidaEn direccion salaInfo of
                        Nothing -> (["No puedes ir hacia alla"], estado)
                        Just (Salida destino requisito) ->
                            case requisito of
                                Just reqObj | reqObj `notElem` inv ->
                                    let (IdObjeto nombreObj) = reqObj
                                    in (["Necesitas " ++ nombreObj ++ " para entrar aqui."], estado)

                                _ ->
                                    let estadoMovido = estado {
                                        salaActual = destino,
                                        turnosRestantes = turnosRestanes estado - 1
                                        }
                                    in (["Te moviste hacia el " ++ nombreDireccion direccion ++ "."], estadoMovido)

        Mirar ->
            let idSala = salaActual estado
            in case buscarSala idSala mundo of
                Nothing -> (["Error de codigo: Escapaste el mundo! Estas en una sala que no existe."], estado)
                Just sala ->
                    let desc = salaDesc sala
                        salidas = Map.keys (salaSalidas sala)
                        textSalidas = if null salidas then "No alcansas a ver salidas..."
                                        else "Puedes ver las salidas: " ++ intercalate ", " (map nombreDireccion salidas)

                        objs = Map.findWithDefault [] idSalaAct (objetoSala estado)
                        textObjs = if null objs then "No hay objetos interesantes"
                                    else "Encontraste los objetos: " ++ intercalate ", " [o | IdObjeto o <- objs]

                        newEstado = estado { turnosRestantes = turnosRestantes - 1}

                    in ([desc, textObjs, textSalida], newEstado)


        Tomar idObj -> (["Aun nada lol"], estado)
        Soltar isObj -> (["Aun nada lol"], estado)
        Examinar idObj -> (["Aun nada lol"], estado)
        Guardar file -> (["Guardando en " ++ file], estado)
        Cargar file -> (["Cargando desde " ++ file], estado)


         _ -> (["No entendí eso, intetna de nuevo, recuerda usar ayuda para ver que puedes hacer"], estado)

    estadoInicial :: Mundo -> Estado
    estadoInicial mundo = Estado {
        salaActual = mundoInicio mundo,
        inventario = [],
        objetosSala = Map.map salaObjetos (mundoSalas mundo),
        turnosRestantes = mundoTurnos mundo
        }
