module Main where
import Test.Hspec
import Motor.Tipos

main :: IO ()
main = hspec $ do
    describe "Motor.Tipos" $ do
        it "reconoce la direccion norte" $ do
            nombreDireccion Norte `shouldBe` "norte"