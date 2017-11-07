-- |
-- Module      : Basement.Sized.Block
-- License     : BSD-style
-- Maintainer  : Haskell Foundation
--
-- A Nat-sized version of Block
{-# LANGUAGE AllowAmbiguousTypes        #-}
{-# LANGUAGE DataKinds                  #-}
{-# LANGUAGE TypeOperators              #-}
{-# LANGUAGE TypeApplications           #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE ConstraintKinds            #-}

module Basement.Sized.Block
    ( BlockN
    , MutableBlockN
    , toBlockN
    , toBlock
    , singleton
    , replicate
    , thaw
    , freeze
    , index
    , indexStatic
    , map
    , foldl'
    , foldr
    , cons
    , snoc
    , elem
    , sub
    , uncons
    , unsnoc
    , splitAt
    , all
    , any
    , find
    , reverse
    , sortBy
    , intersperse
    ) where

import           Data.Proxy (Proxy(..))
import           Basement.Compat.Base
import           Basement.Block (Block, MutableBlock(..), unsafeIndex)
import qualified Basement.Block as B
import           Basement.Monad (PrimMonad, PrimState)
import           Basement.Nat
import           Basement.Types.OffsetSize
import           Basement.NormalForm
import           Basement.PrimType (PrimType)
import           Basement.Types.OffsetSize (CountOf(..), Offset(..), offsetSub)

newtype BlockN (n :: Nat) a = BlockN { unBlock :: Block a } deriving (NormalForm, Eq, Show)

newtype MutableBlockN (n :: Nat) ty st = MutableBlockN { unMBlock :: MutableBlock ty st }

toBlockN :: forall n ty . (PrimType ty, KnownNat n, Countable ty n) => Block ty -> Maybe (BlockN n ty)
toBlockN b
    | expected == B.length b = Just (BlockN b)
    | otherwise = Nothing
  where
    expected = toCount @n

toBlock :: BlockN n ty -> Block ty
toBlock = unBlock

singleton :: PrimType ty => ty -> BlockN 1 ty
singleton a = BlockN (B.singleton a)

replicate :: forall n ty . (KnownNat n, Countable ty n, PrimType ty) => ty -> BlockN n ty
replicate a = BlockN (B.replicate (toCount @n) a)

thaw :: (KnownNat n, PrimMonad prim, PrimType ty) => BlockN n ty -> prim (MutableBlockN n ty (PrimState prim))
thaw b = MutableBlockN <$> B.thaw (unBlock b)

freeze ::  (PrimMonad prim, PrimType ty, Countable ty n) => MutableBlockN n ty (PrimState prim) -> prim (BlockN n ty)
freeze b = BlockN <$> B.freeze (unMBlock b)

indexStatic :: forall i n ty . (KnownNat i, CmpNat i n ~ 'LT, PrimType ty, Offsetable ty i) => BlockN n ty -> ty
indexStatic b = unsafeIndex (unBlock b) (toOffset @i)

index :: forall i n ty . PrimType ty => BlockN n ty -> Offset ty -> ty
index b ofs = B.index (unBlock b) ofs

map :: (PrimType a, PrimType b) => (a -> b) -> BlockN n a -> BlockN n b
map f b = BlockN (B.map f (unBlock b))

foldl' :: PrimType ty => (a -> ty -> a) -> a -> BlockN n ty -> a
foldl' f acc b = B.foldl' f acc (unBlock b)

foldr :: PrimType ty => (ty -> a -> a) -> a -> BlockN n ty -> a
foldr f acc b = B.foldr f acc (unBlock b)

cons :: PrimType ty => ty -> BlockN n ty -> BlockN (n+1) ty
cons e = BlockN . B.cons e . unBlock

snoc :: PrimType ty => BlockN n ty -> ty -> BlockN (n+1) ty
snoc b = BlockN . B.snoc (unBlock b)

sub :: forall i j n ty
     . ( (i <=? n) ~ 'True
       , (j <=? n) ~ 'True
       , (i <=? j) ~ 'True
       , PrimType ty
       , KnownNat i
       , KnownNat j
       , Offsetable ty i
       , Offsetable ty j )
    => BlockN n ty
    -> BlockN (j-i) ty
sub block = BlockN (B.sub (unBlock block) (toOffset @i) (toOffset @j))

uncons :: forall n ty . (CmpNat 0 n ~ 'LT, PrimType ty, KnownNat n, Offsetable ty n)
       => BlockN n ty
       -> (ty, BlockN (n-1) ty)
uncons b = (indexStatic @0 b, BlockN (B.sub (unBlock b) 1 (toOffset @n)))

unsnoc :: forall n ty . (CmpNat 0 n ~ 'LT, KnownNat n, PrimType ty, Offsetable ty n)
       => BlockN n ty
       -> (BlockN (n-1) ty, ty)
unsnoc b =
    ( BlockN (B.sub (unBlock b) 0 (toOffset @n `offsetSub` 1))
    , unsafeIndex (unBlock b) (toOffset @n `offsetSub` 1))

splitAt :: forall i n ty . (CmpNat i n ~ 'LT, PrimType ty, KnownNat i, Countable ty i) => BlockN n ty -> (BlockN i ty, BlockN (n-i) ty)
splitAt b =
    let (left, right) = B.splitAt (toCount @i) (unBlock b)
     in (BlockN left, BlockN right)

elem :: PrimType ty => ty -> BlockN n ty -> Bool
elem e b = B.elem e (unBlock b)

all :: PrimType ty => (ty -> Bool) -> BlockN n ty -> Bool
all p b = B.all p (unBlock b)

any :: PrimType ty => (ty -> Bool) -> BlockN n ty -> Bool
any p b = B.any p (unBlock b)

find :: PrimType ty => (ty -> Bool) -> BlockN n ty -> Maybe ty
find p b = B.find p (unBlock b)

reverse :: PrimType ty => BlockN n ty -> BlockN n ty
reverse = BlockN . B.reverse . unBlock

sortBy :: PrimType ty => (ty -> ty -> Ordering) -> BlockN n ty -> BlockN n ty
sortBy f b = BlockN (B.sortBy f (unBlock b))

intersperse :: (CmpNat n 1 ~ 'GT, PrimType ty) => ty -> BlockN n ty -> BlockN (n+n-1) ty
intersperse sep b = BlockN (B.intersperse sep (unBlock b))

toCount :: forall n ty . (KnownNat n, Countable ty n) => CountOf ty
toCount = natValCountOf (Proxy @n)

toOffset :: forall n ty . (KnownNat n, Offsetable ty n) => Offset ty
toOffset = natValOffset (Proxy @n)
