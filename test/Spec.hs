module Main where
import Test.Hspec
import Motor.Tipos
import PruebasMundo (spec)

main :: IO ()
main = hspec $ do
    describe "Motor.Tipos" $ do
        it "reconoce la direccion norte" $ do
            nombreDireccion Norte `shouldBe` "norte"
    spec
