module Types where
import Text.PrettyPrint.Leijen as PP
import Control.Monad.Instances

type TypeVar = Int 

type FreshPool = [TypeVar]

data Type = Arrow Type Type
          | Pair Type Type
          | Nat
          | Bool
          | Tvar TypeVar
          deriving (Eq, Show)


ppType :: Type -> String
ppType t = show (aux t False)
  where aux (Arrow t1 t2) c =
          (if c then parens else id)  
          ((aux t1 True) <> PP.text "->" <> (aux t2 False))
        aux Nat _ = PP.text "Nat"
        aux Bool _ = PP.text"Bool"
        aux (Tvar a) _ = PP.text ("a" ++ show a)
        aux (Pair t1 t2) _  =
          (aux  t1 False) <> PP.text "*" <> (aux t2 False)
    
data TypeScheme = SimpleType Type
                | ForEach TypeVar TypeScheme
                deriving (Show, Eq)
                       
type TypeEnv = [(STerm, TypeScheme)]

data TypeSubst = Id
               | Sub TypeVar Type
               | Composition TypeSubst TypeSubst

-- Datatype for the sugared AST
data STerm = SAbs String STerm
           | SApp STerm STerm
           | SId String
           | IfThenElse STerm STerm STerm
           | Num Integer
           | Boolean Bool
           | LetIn String STerm STerm
           | LetRec String STerm STerm
           | Plus STerm STerm
           | Mult STerm STerm
           | Minus STerm STerm
           | Pow STerm STerm
           | SPair STerm STerm
           deriving (Show, Eq) 

data TypedSTerm = TAbs (String, Type) (TypedSTerm, Type)
                | TApp TypedSTerm TypedSTerm
                | TId String
                | TIfThenElse TypedSTerm TypedSTerm TypedSTerm
                | TNum Integer
                | TBoolean Bool
                | TLetIn (String, Type) TypedSTerm TypedSTerm
                | TLetRec (String, Type) TypedSTerm TypedSTerm
                | TPlus TypedSTerm TypedSTerm
                | TMult TypedSTerm TypedSTerm
                | TMinus TypedSTerm TypedSTerm
                | TPow TypedSTerm TypedSTerm
                | TPair TypedSTerm TypedSTerm
                deriving Eq

ppTTerm :: TypedSTerm -> String
ppTTerm term = showWidth 60 $ aux term minprec
  where
    showWidth :: Int -> Doc -> String
    showWidth w x   = PP.displayS (PP.renderPretty 0.4 w x) ""

    aux :: TypedSTerm -> Int -> Doc
    aux (TId x) _ = PP.text x
    aux (TNum i) _ = PP.integer i
    aux (TBoolean b) _ = boolean b
    aux (TPair e1 e2) c = 
      PP.list [aux e1 minprec, aux e2 minprec]
    aux e@(TLetIn (ident, t) e1 e2) c = 
      let c' = prec e in
      (if (c' > c) then PP.parens else id) $
      PP.nest 2 (PP.text ("let " ++ ident ++ " : " ++ ppType t ++ " =") <$>
                 aux e1 minprec) <$>
      PP.nest 2 (PP.text "in" <$>
                 aux e2 c')
    aux e@(TLetRec (ident, t) e1 e2) c = 
      let c' = prec e in
      (if (c' > c) then PP.parens else id) $
      PP.nest 2 (PP.text ("let rec " ++ ident ++ " : " ++ ppType t ++ " =") <$>
                 aux e1 minprec) <$>
      PP.nest 2 (PP.text "in" <$>
                  aux e2 c')
    aux e@(TAbs (x, t1) (e2, t2)) c = lam x t1 e2 e c
    aux e@(TApp e1 e2) c = left e1 " " e2 e c
    aux e@(TIfThenElse e1 e2 e3) c = 
      let c' = prec e in
      (if (c' > c) then PP.parens else id) $
      PP.nest 2 (PP.text "if" </> aux e1 c) <$>
      PP.nest 2 (PP.text "then" </> aux e2 c) <$>
      PP.nest 2 (PP.text "else" </> aux e3 c)
    aux e@(TPlus e1 e2) c = left e1 "+" e2 e c
    aux e@(TMinus e1 e2) c = left e1 "-" e2 e c
    aux e@(TMult e1 e2) c = left e1 "*" e2 e c
    aux e@(TPow e1 e2) c = right e1 "**" e2 e c

    lam x typ e ex c =
      let c' = prec ex in
      (if (c' > c) then PP.parens else id) $
      PP.nest 2 ((PP.text ("\\" ++ x ++ " : " ++ ppType typ ++ " . ")) </>
      (aux e c'))
      
    left a op b e c =
      let c' = prec e in
      (if (c' > c) then PP.parens else id) $
      (aux a c') <> PP.text op <> (assoc b c') 

    right a op b e c =
      let c' = prec e in
      (if (c' > c) then PP.parens else id) $
      (assoc a c') <> PP.text op <> (aux b c')

    assoc e c =
      let c' = prec e in
      (if (c == c') then PP.parens else id) $
      aux e c 

    boolean True = PP.text "true"
    boolean False = PP.text "false"

    prec (TId _) = 0
    prec (TNum _ ) = 0
    prec (TLetIn _ _ _) = 0 -- not sure
    prec (TLetRec _ _ _) = 0
    prec (TPair _ _) = 0
    prec (TBoolean _) = 0
    prec (TApp _ _) = 1
    prec (TPow _ _) = 2
    prec (TMult _ _) = 3
    prec (TPlus _ _) = 4
    prec (TMinus _ _) = 4
    prec (TAbs _ _) = 5
    prec (TIfThenElse _ _ _) = 5
    minprec = 6 
        
    
-- Datatype for the desugared AST
data Term = Abs String Term
          | Fix Term
          | App Term Term
          | Ident String 
          deriving Eq

ppTerm :: Term -> String
ppTerm term = show $ aux term 0
  where
    aux (Ident id) _ = PP.text id 
    aux (Abs x e) c =
      (if c > 0 then parens else id)
      ((PP.text ("\\" ++ x ++ " . ")) <>
       (aux e 0))
    aux (App e1 e2) c = 
      (if c > 1 then PP.parens else id)
      (aux e1 1 <+> aux e2 2)
    aux (Fix e) c = PP.parens $
      PP.text "fix" <+> aux e c
    
data Node = Node {
  nodeExpr  :: Term,
  tExpr     :: TypedSTerm,
  typ       :: Type,
  subst     :: TypeSubst,
  pool      :: FreshPool
  }
