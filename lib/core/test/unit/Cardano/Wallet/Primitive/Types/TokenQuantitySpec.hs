{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeApplications #-}

{-# OPTIONS_GHC -fno-warn-orphans #-}

module Cardano.Wallet.Primitive.Types.TokenQuantitySpec
    ( spec
    ) where

import Prelude

import Cardano.Wallet.Primitive.Types.TokenQuantity
    ( TokenQuantity (..) )
import Data.Aeson
    ( FromJSON (..), ToJSON (..) )
import Data.Proxy
    ( Proxy (..) )
import Data.Text.Class
    ( ToText (..) )
import Data.Typeable
    ( Typeable )
import System.FilePath
    ( (</>) )
import Test.Hspec
    ( Spec, describe, it, parallel )
import Test.Hspec.Core.QuickCheck
    ( modifyMaxSuccess )
import Test.QuickCheck
    ( Arbitrary (..), Property, choose, elements, oneof, property, (===) )
import Test.QuickCheck.Classes
    ( eqLaws
    , monoidLaws
    , ordLaws
    , semigroupLaws
    , semigroupMonoidLaws
    , showReadLaws
    )
import Test.Text.Roundtrip
    ( textRoundtrip )
import Test.Utils.Laws
    ( testLawsMany )
import Test.Utils.Paths
    ( getTestData )

import qualified Cardano.Wallet.Primitive.Types.TokenQuantity as TQ
import qualified Data.Char as Char
import qualified Data.Foldable as F
import qualified Data.Text as T
import qualified Test.Utils.Roundtrip as JsonRoundtrip

spec :: Spec
spec =
    describe "Token quantity properties" $
    modifyMaxSuccess (const 1000) $ do

    parallel $ describe "Class instances obey laws" $ do
        testLawsMany @TokenQuantity
            [ eqLaws
            , monoidLaws
            , ordLaws
            , semigroupLaws
            , semigroupMonoidLaws
            , showReadLaws
            ]

    parallel $ describe "Operations" $ do

        it "prop_negate" $
            property prop_negate
        it "prop_negate_negate" $
            property prop_negate_negate
        it "prop_pred_succ" $
            property prop_pred_succ
        it "prop_succ_pred" $
            property prop_succ_pred

    parallel $ describe "JSON serialization" $ do

        describe "Roundtrip tests" $ do
            testJson $ Proxy @TokenQuantity

    parallel $ describe "Text serialization" $ do

        describe "Roundtrip tests" $ do
            textRoundtrip $ Proxy @TokenQuantity
        it "prop_toText_noQuotes" $ do
            property prop_toText_noQuotes

--------------------------------------------------------------------------------
-- Operations
--------------------------------------------------------------------------------

prop_negate :: TokenQuantity -> Property
prop_negate = property . \case
    q | TQ.isStrictlyNegative q ->
        TQ.isStrictlyPositive $ TQ.negate q
    q | TQ.isStrictlyPositive q ->
        TQ.isStrictlyNegative $ TQ.negate q
    q ->
        TQ.isZero q

prop_negate_negate :: TokenQuantity -> Property
prop_negate_negate q = TQ.negate (TQ.negate q) === q

prop_pred_succ :: TokenQuantity -> Property
prop_pred_succ q =
    TQ.succ (TQ.pred q) === q

prop_succ_pred :: TokenQuantity -> Property
prop_succ_pred q =
    TQ.pred (TQ.succ q) === q

--------------------------------------------------------------------------------
-- JSON serialization
--------------------------------------------------------------------------------

testJson
    :: (Arbitrary a, ToJSON a, FromJSON a, Typeable a) => Proxy a -> Spec
testJson = JsonRoundtrip.jsonRoundtripAndGolden testJsonDataDirectory

testJsonDataDirectory :: FilePath
testJsonDataDirectory =
    ($(getTestData) </> "Cardano" </> "Wallet" </> "Primitive" </> "Types")

--------------------------------------------------------------------------------
-- Text serialization
--------------------------------------------------------------------------------

prop_toText_noQuotes :: TokenQuantity -> Property
prop_toText_noQuotes q = property $ case text of
    c : cs ->
        Char.isDigit c || c == '-' && F.all Char.isDigit cs
    [] ->
        error "Unexpected empty string."
  where
    text = T.unpack $ toText q

--------------------------------------------------------------------------------
-- Test constants
--------------------------------------------------------------------------------

smallNegativeValue :: Integer
smallNegativeValue = Prelude.negate smallPositiveValue

smallPositiveValue :: Integer
smallPositiveValue = 100

largeNegativeValue :: Integer
largeNegativeValue = Prelude.negate largePositiveValue

largePositiveValue :: Integer
largePositiveValue = (10 :: Integer) ^ (1000 :: Integer)

--------------------------------------------------------------------------------
-- Arbitrary instances
--------------------------------------------------------------------------------

instance Arbitrary TokenQuantity where
    -- Note that we generate token quantities with a variety of magnitudes.
    -- In particular, we need to be sure that roundtrip serialization works
    -- with token quantities of all magnitudes.
    arbitrary = TokenQuantity <$> oneof
        [ elements [-1, 0, 1]
        , elements [largeNegativeValue, largePositiveValue]
        , choose (smallNegativeValue, smallPositiveValue)
        , choose (largeNegativeValue, largePositiveValue)
        ]
    shrink (TokenQuantity q) =
        TokenQuantity <$> shrink q
