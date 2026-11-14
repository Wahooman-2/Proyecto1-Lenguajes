module Motor.Nucleo where

    import Motor.Tipos
    import Data.List
    import qualified Data.Map as Map
    import Data.List (delete)

    ejecutar :: Mundo -> Comando -> Estado -> ([String], Estado)
    ejecutar mundo comando estado = case comando of

        Salir -> (["Hasta pronto! Saliendo..."], estado)
        Ayuda -> (["Puedes usar: ir <direccion>, mirar, tomar <objeto>, soltar <objeto>, examinar <objeto>, inventario, guardar <archivo>, cargar <archivo>, ayuda, salir"], estado)

        Inventario -> let inv = inventario estado
                            msg = if null inv then "No llevas nada."
                            else "" ++ intercalate ", " [o | IdObjeto o <- inv]
                        in ([msg], estado)

        Ir direccion ->
            let idSalaAct = salaActual estado
                inv = inventario estado

            in case buscarSala idSalaAct mundo of
                Nothing -> (["Error de codigo: Escapaste el mundo! Estas en una sala que no existe."], estado)
                Just sala ->
                    case salidaEn direccion sala of
                        Nothing -> (["No puedes ir hacia alla"], estado)
                        Just (Salida destino requisito) ->
                            case requisito of
                                Just reqObj | reqObj `notElem` inv ->
                                    let (IdObjeto nombreObj) = reqObj
                                    in (["Necesitas " ++ nombreObj ++ " para entrar aqui."], estado)

                                _ ->
                                    let estadoMovido = estado {
                                        salaActual = destino,
                                        turnosRestantes = turnosRestantes estado - 1
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

                        objs = Map.findWithDefault [] idSala (objetosSala estado)
                        textObjs = if null objs then "No hay objetos interesantes"
                                    else "Encontraste los objetos: " ++ intercalate ", " [o | IdObjeto o <- objs]

                        newEstado = estado { turnosRestantes = turnosRestantes estado - 1}

                    in ([desc, textObjs, textSalidas], newEstado)

        Tomar idObj ->
            let sala = salaActual estado
                inv = inventario estado
                mapObjs = objetosSala estado
                objsSala = Map.findWithDefault [] sala mapObjs
            in if idObj `notElem` objsSala then (["Estas viendo cosas, eso no esta aqui."], estado)
            else
                let nuevosObjsSala = delete idObj objsSala
                    nuevoMapObjs = Map.insert sala nuevosObjsSala mapObjs
                    newInv = idObj : inv
                    nuevoEstado = estado {
                        inventario = newInv,
                        objetosSala = nuevoMapObjs,
                        turnosRestantes = turnosRestantes estado - 1
                        }

                    (IdObjeto nombreObj) = idObj
                in (["Guardaste: " ++ nombreObj ++ " en tu inventario."], newEstado)

        Soltar idObj ->
            let sala = salaActual estado
                inv = inventario estado
                mapObjs = objetosSala estado
            in if idObj `notElem` inv then (["No tienes eso..."], estado)
            else
                let newInv = delete idObj inv
                    objsSala = Map.findWithDefault [] sala mapObjs
                    newObjsSala = idObj : objsSala
                    newMapObjs = Map.insert sala newObjsSala mapObjs

                    newEstado = estado {
                        inventario = newInv,
                        objetosSala = newMapObjs,
                        turnosRestantes = turnosRestantes estado - 1
                        }
                    (IdObjeto nombreObj) = idObj
                in (["Soltaste: " ++ nombreObj ++ "."], nuevoEstado)

        Examinar idObj ->
            let sala = salaActual estado
                inv = inventario estado
                objsSala = Map.findWithDefault [] sala (objetosSala estado)
            in if idObj `notElem` inv && idObj `notElem` objsSala then (["Ese objeto no esta tu alcance."], estado)
            else
                case buscarObjeto idObj mundo of
                    Nothing -> (["Error de codigo: Conseguiste un objeto que no existe!"], estado)
                    Just objInfo ->
                        let desc = objetoDesc objInfo
                            newEstado = estado {
                                turnosRestantes = turnosRestantes estado - 1
                            }
                        in ([desc], newEstado)

        Guardar file -> (["Guardando en " ++ file], estado)

        Cargar file -> (["Cargando desde " ++ file], estado)


        _ -> (["No entendí eso, intenta de nuevo, recuerda usar ayuda para ver que puedes hacer"], estado)

    estadoInicial :: Mundo -> Estado
    estadoInicial mundo = Estado {
        salaActual = mundoInicio mundo,
        inventario = [],
        objetosSala = Map.map salaObjetos (mundoSalas mundo),
        turnosRestantes = mundoTurnos mundo
        }

    evaluarEstado :: Mundo -> Estado -> Fin
    evaluarEstado mundo estado
        | metaCumplida (mundoMeta mundo) estado = Ganar
        | turnosRestantes estado <= 0 = FinTurnos
        | otherwise = Continuar

    metaCumplida :: Meta -> Estado -> Bool
    metaCumplida (LlegarA salaDestino) estado = salaActual estado == salaDestino
    metaCumplida (LlevarA objRequerido salaDestino) estado = salaActual estado == salaDestino && objRequerido `elem` inventario estado