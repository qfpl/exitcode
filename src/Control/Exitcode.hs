module Control.Exitcode (
                        -- * Types
                          ExitcodeT
                        , Exitcode
                        , ExitcodeT0
                        , Exitcode0
                        -- * Constructors
                        , exitsuccess
                        , exitsuccess0
                        , exitfailure0
                        , runExitcode
                        -- * Optics
                        , exitCode
                        , _ExitFailure
                        , _ExitSuccess
                        ) where

import           Control.Applicative     (Applicative, liftA2)
import           Control.Lens            hiding ((<.>))
import           Control.Monad.IO.Class  (MonadIO (liftIO))
import           Data.Functor.Alt        (Alt, (<!>))
import           Data.Functor.Apply      (Apply, liftF2, (<.>))
import           Data.Functor.Bind       (Bind, (>>-))
import           Data.Functor.Classes    (Eq1, Ord1, Show1, compare1, eq1,
                                          showsPrec1, showsUnaryWith)
import           Data.Functor.Extend     (Extend, duplicated)
import           Data.Semigroup          (Semigroup, (<>))
import           Data.Semigroup.Foldable (Foldable1)
import           System.Exit             (ExitCode (..))

-- hide the constructor, `Left 0` is an invalid state
data ExitcodeT f a =
  ExitcodeT (f (Either Int a))

type Exitcode a =
  ExitcodeT Identity a

type ExitcodeT0 f =
  ExitcodeT f ()

type Exitcode0 =
  Exitcode ()

exitsuccess ::
  Applicative f =>
  a
  -> ExitcodeT f a
exitsuccess =
  ExitcodeT . pure . Right

exitsuccess0 ::
  Applicative f =>
  ExitcodeT0 f
exitsuccess0 =
  exitsuccess ()

exitfailure0 ::
  Applicative f =>
  Int
  -> ExitcodeT0 f
exitfailure0 n =
  if n == 0
    then
      exitsuccess0
    else
      ExitcodeT . pure . Left $ n

exitCode ::
  Functor f =>
  Iso'
    (ExitcodeT0 f)
    (f ExitCode)
exitCode =
  iso
    (\(ExitcodeT x) -> either ExitFailure (const ExitSuccess) <$> x)
    (\x -> let ex ExitSuccess     = Right ()
               ex (ExitFailure 0) = Right ()
               ex (ExitFailure n) = Left n
           in  ExitcodeT (ex <$> x))

runExitcode ::
  ExitcodeT f a
  -> f (Either Int a)
runExitcode (ExitcodeT x) =
  x

_ExitFailure ::
  Prism'
    Exitcode0
    Int
_ExitFailure =
  prism'
    exitfailure0
    (\(ExitcodeT (Identity x)) -> x ^? _Left)

_ExitSuccess ::
  Prism'
    Exitcode0
    ()
_ExitSuccess =
  prism'
    (\() -> exitsuccess0)
    (\(ExitcodeT (Identity x)) -> x ^? _Right)

instance Functor f => Functor (ExitcodeT f) where
  fmap f (ExitcodeT x) =
    ExitcodeT (fmap (fmap f) x)

instance Apply f => Apply (ExitcodeT f) where
  ExitcodeT f <.> ExitcodeT a =
    ExitcodeT (liftF2 (<.>) f a)

instance Applicative f => Applicative (ExitcodeT f) where
  pure =
    ExitcodeT . pure . pure
  ExitcodeT f <*> ExitcodeT a =
    ExitcodeT (liftA2 (<*>) f a)

instance (Bind f, Monad f) => Bind (ExitcodeT f) where
  (>>-) =
    (>>=)

instance Monad f => Monad (ExitcodeT f) where
  return =
    ExitcodeT . return . return
  ExitcodeT x >>= f =
    ExitcodeT
      (x >>= either (pure . Left) (\a -> let ExitcodeT y = f a in y))

instance Monad f => Alt (ExitcodeT f) where
  ExitcodeT a <!> ExitcodeT b =
    ExitcodeT (a >>= either (const b) (pure a))

instance Monad f => Semigroup (ExitcodeT f a) where
  ExitcodeT a <> ExitcodeT b =
    ExitcodeT (a >>= either (const b) (pure a))

instance Applicative f => Extend (ExitcodeT f) where
  duplicated (ExitcodeT x) =
    ExitcodeT ((pure <$>) <$> x )

instance (Eq1 f, Eq a) => Eq (ExitcodeT f a) where
  ExitcodeT a == ExitcodeT b =
    a `eq1` b

instance (Ord1 f, Ord a) => Ord (ExitcodeT f a) where
  ExitcodeT a `compare` ExitcodeT b =
    a `compare1` b

instance (Show1 f, Show a) => Show (ExitcodeT f a) where
  showsPrec d (ExitcodeT m) =
    showsUnaryWith showsPrec1 "ExitcodeT" d m

instance Foldable f => Foldable (ExitcodeT f) where
  foldr f z (ExitcodeT x) =
    foldr (flip (foldr f)) z x

instance Foldable1 f => Foldable1 (ExitcodeT f)

instance Traversable f => Traversable (ExitcodeT f) where
  traverse f (ExitcodeT x) =
    ExitcodeT <$> traverse (traverse f) x

instance MonadIO f => MonadIO (ExitcodeT f) where
  liftIO io =
    ExitcodeT (Right <$> liftIO io)
