(* ********************* *)
(* Author: Yuting Wang   *)
(* Date:   Oct 31, 2019   *)
(* ********************* *)

Require Import Coqlib Integers AST Maps.
Require Import Asm.
Require Import Errors.
Require Import Memtype.
Require Import Asm RelocProgram.
Require Import Symbtablegen.
Require Import Linking LinkingProp OrderedLinking.
Require Import RelocLinking.
Require Import SeqTable.
Require Import RelationClasses.
Require Import RelocProgSyneq.
Import ListNotations.

Set Implicit Arguments.

Local Transparent Linker_def.
Local Transparent Linker_fundef.
Local Transparent Linker_vardef.
Local Transparent Linker_varinit.

Lemma map_pres_subset_rel: forall A B (l1 l2:list A) (f: A -> B),
    (forall x, In x l1 -> In x l2)
    -> (forall y, In y (map f l1) -> In y (map f l2)).
Proof.
  intros A B l1 l2 f SUB y IN.
  rewrite in_map_iff in *.
  destruct IN as (x & EQ & IN). subst.
  eauto.
Qed.

Lemma Forall_app_distr: forall A f (l1 l2 : list A),
    Forall f (l1 ++ l2) 
    <-> Forall f l1 /\ Forall f l2.
Proof.
  induction l1 as [|e l1].
  - intros l2. cbn. split; auto.
    tauto.
  - cbn. intros. generalize (IHl1 l2).
    destruct 1 as [F1 F2].
    split.
    + intros F3. inv F3.
      generalize (F1 H2). 
      destruct 1. split; auto.
    + intros F3. destruct F3 as [F4 F5]. inv F4.
      auto.
Qed.


Lemma length_S_inv : forall A n (l: list A),
    length l = S n ->
    exists l' a, l = l' ++ [a] /\ length l' = n.
Proof.
  induction n.
  - intros. destruct l. cbn in *.
    congruence.
    cbn in H. inv H.
    rewrite length_zero_iff_nil in H1.
    subst. exists nil. cbn. eauto.
  - intros. simpl in *. 
    destruct l. cbn in H. congruence.
    cbn in H. inv H.
    generalize (IHn _ H1).
    destruct 1 as (l' & a0 & eq & LEN). subst.
    exists (a :: l'). cbn. eexists; split; eauto.
Qed.

Lemma rev_nil_inv_len : forall A n (l:list A),
    length l = n -> rev l = [] -> l = nil.
Proof.
  induction n.
  - intros. 
    rewrite length_zero_iff_nil in H. subst. auto.
  - intros.
    generalize (length_S_inv _ H).
    destruct 1 as (l' & a & EQ & LEN).
    subst. rewrite rev_unit in H0.
    inv H0.
Qed.

Lemma rev_nil_inv : forall A (l:list A),
    rev l = [] -> l = nil.
Proof.
  intros. eapply rev_nil_inv_len; eauto.
Qed.

Lemma rev_single : forall A (l:list A) a,
    rev l = [a] -> l = [a].
Proof.
  induction l.
  - cbn in *. congruence.
  - intros. simpl in H.
    replace [a0] with (nil ++ [a0]) in H by auto.
    apply app_inj_tail in H.
    destruct H; subst. 
    generalize (rev_nil_inv _ H).
    intros. subst. auto.
Qed.

Lemma app_cons_comm : forall (A:Type) (l1 l2: list A) a,
    l1 ++ (a :: l2) = (l1 ++ [a]) ++ l2.
Proof.
  induction l1.
  - intros. auto.
  - simpl. intros. rewrite IHl1. auto.
Qed.

Lemma list_norepet_app: forall A (l1 l2: list A),
    list_norepet l1 -> list_norepet l2 
    -> (forall a, In a l1 -> ~ In a l2)
    -> list_norepet (l1 ++ l2).
Proof.
  induction l1; intros until l2; intros NORPT1 NORPT2 EXCL.
  - cbn. auto.
  - cbn in *. inv NORPT1.
    constructor. 
    + rewrite in_app.
      intro IN. destruct IN as [IN|IN]; auto.
      eapply EXCL; eauto.
    + eapply IHl1; eauto.
Qed.

Lemma partition_inv_nil1 : forall (A:Type) f (l1 l2:list A),
    partition f l1 = ([], l2) -> l1 = l2.
Proof.
  induction l1; intros; simpl in *.
  - inv H. auto.
  - destr_in H. destr_in H. inv H.
    f_equal. apply IHl1; auto.
Qed.

Lemma elements_in_partition_prop: forall A f (l l1 l2: list A),
    partition f l = (l1, l2) -> 
    (forall x, In x l1 -> f x = true) /\ (forall x, In x l2 -> f x = false).
Proof.
  induction l; intros until l2; simpl.
  - inversion 1. subst. 
    split; intros; simpl in *; contradiction.
  - intros PART. destr_in PART. 
    generalize (IHl _ _ (@eq_refl _ (l0, l3))).
    destruct 1 as (IN1 & IN2).
    destr_in PART; inv PART; split; intros; auto.
    inv H; auto.
    inv H; auto.
Qed.

Lemma defs_in_partition_id_not_in : 
  forall F V (LV: Linker V)
    id (l l1 l2: list (ident * option (globdef (AST.fundef F) V))),
    partition (fun '(id', _) => ident_eq id' id) l = (l1, l2) 
    -> ~ In id (map fst l2).
Proof. 
  intros F V LV id l l1 l2 PART.
  apply elements_in_partition_prop in PART.
  destruct PART.
  rewrite in_map_iff. intro IN.
  destruct IN as (def & EQ & IN3).
  generalize (H0 _ IN3). destruct def. 
  inv EQ. cbn. 
  destruct peq; auto. intros. inv H1.
Qed.

Lemma part_not_in_nil : forall F V id (defs defs' l: list (ident * option (globdef (AST.fundef F) V))),
    partition (fun '(id', _) => ident_eq id' id) defs = (l, defs') ->
    ~ In id (map fst defs) ->
    l = nil.
Proof.
  induction defs. 
  - intros defs' l PART NIN.
    simpl in *. inv PART. auto.
  - intros defs' l PART NIN.
    simpl in *. destr_in PART. 
    destruct a, ident_eq; simpl in *; subst; inv PART.
    exfalso. apply NIN. auto.
    eapply IHdefs; eauto.
Qed.

Lemma lst_norepet_partition_inv : forall F V id (defs defs1 defs2: list (ident * option (globdef (AST.fundef F) V))),
    list_norepet (map fst defs) ->
    partition (fun '(id', _) => ident_eq id' id) defs = (defs1, defs2) ->
    defs1 = nil \/ exists def, defs1 = [def].
Proof.
  induction defs.
  - intros defs1 defs2 NORPT PART.
    simpl in *. inv PART. auto.
  - intros defs1 defs2 NORPT PART.
    simpl in *. inv NORPT.
    destr_in PART. destruct a.
    destruct ident_eq; simpl in *; inv PART.
    + generalize (part_not_in_nil _ _ Heqp H1).
      intros. subst.
      eauto.
    + eauto.
Qed.

Lemma partition_pres_list_norepet : forall F V f (l l1 l2: list (ident * option (globdef (AST.fundef F) V))),
    partition f l = (l1, l2) -> 
    list_norepet (map fst l) ->
    list_norepet (map fst l1) /\ list_norepet (map fst l2).
Proof.
  induction l.
  - intros l1 l2 PART NORPT.
    simpl in *. inv PART. auto.
  - intros l1 l2 PART NORPT.
    simpl in *. inv NORPT. destr_in PART.
    destr_in PART. 
    + inv PART.
      generalize (IHl _ _ (@eq_refl _ (l0, l2)) H2).
      destruct 1. split; auto. simpl. constructor; auto.
      intro IN. apply H1. 
      generalize (elements_in_partition _ _ Heqp).
      intros ELEM.
      apply list_in_map_inv in IN. 
      destruct IN as (b & EQ & IN). 
      rewrite in_map_iff.
      exists b.  split; auto.
      rewrite ELEM. auto.
    + inv PART.
      generalize (IHl _ _ (@eq_refl _ (l1, l3)) H2).
      destruct 1.
      split; auto.
      simpl. constructor; auto.
      intro IN. apply H1.
      generalize (elements_in_partition _ _ Heqp).
      intros ELEM.
      rewrite in_map_iff in *.
      destruct IN as (x & EQ & IN).
      eexists; split; eauto.
      rewrite ELEM. auto.
Qed.

        
Lemma get_symbentry_id : forall d_id c_id dsz csz id def,
    symbentry_id (get_symbentry d_id c_id dsz csz id def) = Some id.
Proof.
  intros until def.
  destruct def. destruct g. destruct f.
  simpl; auto.
  simpl; auto.
  simpl. destruct (gvar_init v); auto. destruct i; auto. destruct l; auto.
  simpl; auto.
Qed.

Lemma get_var_entry_size : forall dsz csz id v, 
    symbentry_size (get_symbentry sec_data_id sec_code_id dsz csz id (Some (Gvar v))) = AST.init_data_list_size (gvar_init v).
Proof.
  intros.
  cbn. destruct (gvar_init v); auto.
  destruct i; auto.
  destruct l; auto.
  cbn. omega.
Qed.

Lemma get_internal_var_entry : forall dsec csec dsz csz id v,
    is_var_internal v = true ->
    get_symbentry dsec csec dsz csz id (Some (Gvar v)) =       
    {|symbentry_id := Some id;
      symbentry_bind := get_bind_ty id;
      symbentry_type := symb_data;
      symbentry_value := dsz;
      symbentry_secindex := secindex_normal (SecIndex.interp dsec);
      symbentry_size := AST.init_data_list_size (AST.gvar_init v);
    |}.
Proof.
  intros dsec csec dsz csz id v INT.
  unfold is_var_internal in INT.
  cbn.
  destruct (gvar_init v); cbn in INT; try congruence.
  destruct i; cbn in INT; try congruence.
  destruct l; cbn in INT; try congruence.
Qed.

Lemma get_comm_var_entry : forall dsec csec dsz csz id v,
    is_var_comm v = true ->
    get_symbentry dsec csec dsz csz id (Some (Gvar v)) =       
    {|symbentry_id := Some id;
      symbentry_bind := get_bind_ty id;
      symbentry_type := symb_data;
      symbentry_value := 8 ; 
      symbentry_secindex := secindex_comm;
      symbentry_size := Z.max (AST.init_data_list_size (gvar_init v)) 0;
    |}.
Proof.
  intros dsec csec dsz csz id v INT.
  unfold is_var_comm in INT.
  cbn.
  destruct (gvar_init v); cbn in INT; try congruence.
  destruct i; cbn in INT; try congruence.
  destruct l; cbn in INT; try congruence.
  cbn. f_equal.
  rewrite Z.add_comm. cbn.
  rewrite (@Z_max_0 (Z.max z 0)). auto.
  apply Z.le_ge.
  apply Z.le_max_r.
Qed.

Lemma get_external_var_entry : forall dsec csec dsz csz id v,
    is_var_extern v = true ->
    get_symbentry dsec csec dsz csz id (Some (Gvar v)) =       
    {|symbentry_id := Some id;
      symbentry_bind := get_bind_ty id;
      symbentry_type := symb_data;
      symbentry_value := 0;
      symbentry_secindex := secindex_undef;
      symbentry_size := 0;
    |}.
Proof.
  intros dsec csec dsz csz id v INT.
  unfold is_var_extern in INT.
  cbn.
  destruct (gvar_init v); cbn in INT; try congruence.
  destruct i; cbn in INT; try congruence.
  destruct l; cbn in INT; try congruence.
Qed.


(** * Commutativity of linking and Symbtablgen *)

Definition match_prog (p: Asm.program) (tp: program) :=
  exists tp', transf_program p = OK tp /\ reloc_prog_syneq tp tp'.


Lemma match_prog_pres_prog_defs : forall p tp,
  match_prog p tp -> AST.prog_defs p = prog_defs tp.
Proof.
  intros p tp MATCH. red in MATCH.
  destruct MATCH as (tp' & MATCH & SEQ).
  unfold transf_program in MATCH.
  destruct check_wellformedness; try monadInv MATCH.
  destruct (gen_symb_table sec_data_id sec_code_id (AST.prog_defs p)) eqn:EQ.
  destruct p0. 
  destruct zle; try monadInv MATCH. simpl. auto.
Qed.

Lemma match_prog_pres_prog_main : forall p tp,
  match_prog p tp -> AST.prog_main p = prog_main tp.
Proof.
  intros p tp MATCH. red in MATCH.
  destruct MATCH as (tp' & MATCH & SEQ).
  unfold transf_program in MATCH.
  destruct check_wellformedness; try monadInv MATCH.
  destruct (gen_symb_table sec_data_id sec_code_id (AST.prog_defs p)) eqn:EQ.
  destruct p0. 
  destruct zle; try monadInv MATCH. simpl. auto.
Qed.

Lemma match_prog_pres_prog_public : forall p tp,
  match_prog p tp -> AST.prog_public p = prog_public tp.
Proof.
  intros p tp MATCH. red in MATCH.
  destruct MATCH as (tp' & MATCH & SEQ).
  unfold transf_program in MATCH.
  destruct check_wellformedness; try monadInv MATCH.
  destruct (gen_symb_table sec_data_id sec_code_id (AST.prog_defs p)) eqn:EQ.
  destruct p0. 
  destruct zle; try monadInv MATCH. simpl. auto.
Qed.

  
Lemma eq_gvar_init_pres_aligned : forall v1 v2,
    gvar_init v1 = gvar_init v2 
    -> def_aligned (Some (Gvar v1))
    -> def_aligned (Some (Gvar v2)).
Proof.
  intros. cbn in *. rewrite <- H.
  auto.
Qed.

Lemma link_varinit_internal_external_pres_aligned:
  forall (v1 v2: globvar unit) l inf rd vl,
    is_var_internal v2 = false
    -> def_aligned (Some (Gvar v1))
    -> link_varinit (gvar_init v1) (gvar_init v2) = Some l
    -> def_aligned (Some (Gvar (mkglobvar inf l rd vl))).
Proof.
  intros v1 v2 l inf rd vl INT2 ALIGN LINK.
  destruct (is_var_internal v1) eqn:INT1.
  - generalize (link_internal_external_varinit _ _ _ INT1 INT2 LINK).
    destruct 1 as (EQ & CLS). subst.   
    apply eq_gvar_init_pres_aligned with v1; auto.
  - generalize (link_external_varinit _ _ _ INT1 INT2 LINK).
    intros CLS.
    destruct l. cbn. auto.
    cbn in *. destruct i; try congruence.
    destruct l; try congruence. auto.
Qed.


Lemma link_vardef_internal_external_pres_aligned:
  forall v1 v2 v,
    is_var_internal v2 = false
    -> def_aligned (Some (Gvar v1))
    -> link_vardef v1 v2 = Some v
    -> def_aligned (Some (Gvar v)).
Proof.
  intros v1 v2 v INT ALIGN LINK.
  unfold link_vardef in LINK. 
  destr_in LINK; try congruence.
  destr_in LINK; try congruence.
  destr_in LINK; try congruence.
  inv LINK. unfold is_var_internal in INT.
  eapply link_varinit_internal_external_pres_aligned; eauto.
Qed.
  

Lemma external_var_aligned: forall v,
    is_var_internal v = false -> def_aligned (Some (Gvar v)).
Proof.
  intros v INT.
  unfold is_var_internal in INT.
  cbn. destruct (gvar_init v); cbn in *; try congruence.
  auto.
  destruct i; cbn in *; try congruence.
  destruct l; cbn in *; try congruence.
  auto.
Qed.


Lemma link_option_internal_external_pres_aligned: forall def1 def2 def,
    is_def_internal is_fundef_internal def2 = false
    -> def_aligned def1
    -> link_option def1 def2 = Some def
    -> def_aligned def.
Proof.
  intros def1 def2 def INT ALIGN LINK.
  destruct def2. destruct g. destruct f; cbn in *; try congruence.
  - destruct def1. destruct g. destruct f. 
    + cbn in LINK. destr_in LINK; try congruence. inv LINK.
      destr_in Heqo; try congruence; inv Heqo.
      destruct e; try congruence. inv Heqo0. auto.
    + cbn in LINK. destr_in LINK; try congruence. inv LINK.
      destr_in Heqo; try congruence; inv Heqo.
      destr_in Heqo0; try congruence. 
    + cbn in LINK. congruence.
    + cbn in LINK. inv LINK. auto.
  - destruct def1. destruct g.
    + cbn in *. congruence.
    + cbn in LINK. destr_in LINK; try congruence.
      destr_in Heqo; try congruence. inv Heqo. inv LINK.
      cbn in INT.
      eapply link_vardef_internal_external_pres_aligned; eauto.
    + cbn in *. inv LINK.       
      eapply external_var_aligned; eauto.
  - destruct def1. cbn in LINK. inv LINK. auto.
    cbn in *. inv LINK. auto.
Qed.
     

(** ** Commutativity of linking and generation of the symbol table *)


Lemma acc_symb_append : forall d_id c_id defs dsz1 csz1 stbl1 dsz2 csz2 stbl2 stbl3,
    fold_left (acc_symb d_id c_id) defs (stbl1, dsz1, csz1) = (stbl2, dsz2, csz2) ->
    fold_left (acc_symb d_id c_id) defs (stbl1 ++ stbl3, dsz1, csz1) = (stbl2 ++ stbl3, dsz2, csz2).
Proof.
  induction defs.
  - intros until stbl2. intros stbl3 ACC. simpl in *.
    inv ACC. auto.
  - intros until stbl2. intros stbl3 ACC. simpl in *.
    destr_in ACC. destruct a. inv Heqp. destr_in ACC.
    rewrite app_comm_cons.
    apply IHdefs. auto.
Qed.

Lemma acc_symb_append_nil : forall d_id c_id defs dsz1 csz1 dsz2 csz2 stbl2 stbl3,
    fold_left (acc_symb d_id c_id) defs ([], dsz1, csz1) = (stbl2, dsz2, csz2) ->
    fold_left (acc_symb d_id c_id) defs (stbl3, dsz1, csz1) = (stbl2 ++ stbl3, dsz2, csz2).
Proof.
  intros until stbl3. intros ACC.
  replace stbl3 with ([] ++ stbl3) by auto.
  apply acc_symb_append. auto.
Qed.


Lemma acc_symb_inv: forall asf d_id c_id defs stbl1 dsz1 csz1 stbl2 dsz2 csz2,
    asf = (acc_symb d_id c_id) ->
    fold_left asf defs (stbl1, dsz1, csz1) = (stbl2, dsz2, csz2) ->
    exists stbl1', stbl2 = stbl1' ++ stbl1 /\
              fold_left asf defs ([], dsz1, csz1) = (stbl1', dsz2, csz2).
Proof.
  induction defs.
  - intros stbl1 dsz1 csz1 stbl2 dsz2 csz2 ASF ACC.
    simpl in *. inv ACC. exists nil. eauto.
  - intros until csz2. intros ASF ACC. simpl in *.
    rewrite ASF in ACC. simpl in ACC. destruct a as (id & def).
    destruct (update_code_data_size dsz1 csz1 def) as [dsize' csize'] eqn:UPDATE.
    rewrite <- ASF in ACC.
    generalize (IHdefs _ _ _ _ _ _ ASF ACC).
    destruct 1 as (stbl1' & EQ & ACC1).
    rewrite app_cons_comm in EQ.
    rewrite EQ.
    eexists. split; auto.
    subst. simpl.
    rewrite UPDATE. 
    apply acc_symb_append_nil. auto.
Qed.

Definition symbentry_index_in_range range e :=
  match symbentry_secindex e with
  | secindex_normal i => In i range
  | _ => True
  end.

Definition symbtable_indexes_in_range range t :=
  Forall (symbentry_index_in_range range) t.

Lemma get_symbentry_in_range: forall d_id c_id dsz csz id def,
  symbentry_index_in_range [SecIndex.interp d_id; SecIndex.interp c_id] (get_symbentry d_id c_id dsz csz id def).
Proof.
  intros.
  destruct def. destruct g. destruct f.
  - cbn. auto.
  - cbn. auto.
  - destruct (is_var_internal v) eqn:INT.
    + rewrite get_internal_var_entry; auto. cbn. auto.
    + rewrite var_not_internal_iff in INT.
      destruct INT as [INT | INT].
      * rewrite get_comm_var_entry; auto. cbn. auto.
      * rewrite get_external_var_entry; auto. cbn. auto.
  - cbn. auto.
Qed.

Lemma acc_symb_index_in_range: forall d_id c_id defs dsz1 csz1 tbl dsz2 csz2,
      fold_left (acc_symb d_id c_id) defs ([], dsz1, csz1) = (tbl, dsz2, csz2)
      -> symbtable_indexes_in_range (map SecIndex.interp [d_id; c_id]) (rev tbl).
Proof.
  induction defs as [| def defs].
  - intros until csz2. intros ACC. cbn in *.
    inv ACC. red. cbn. apply Forall_nil.
  - intros until csz2. intros ACC. cbn in *.
    destruct def as [id def]. destr_in ACC.
    generalize (acc_symb_inv _ _ _ _ eq_refl ACC).
    destruct 1 as (stbl1' & EQ & ACC'). subst.
    rewrite rev_unit.
    generalize (IHdefs _ _ _ _ _ ACC').
    intros IN_RNG.
    red. rewrite Forall_forall.
    intros x IN.
    inv IN.
    + apply get_symbentry_in_range.
    + red in IN_RNG.
      rewrite Forall_forall in IN_RNG.
      apply IN_RNG; auto.
Qed.

Lemma gen_symb_table_index_in_range : forall defs sec_data_id sec_code_id stbl dsz csz,
    gen_symb_table sec_data_id sec_code_id defs = (stbl, dsz, csz) ->
    symbtable_indexes_in_range (map SecIndex.interp [sec_data_id; sec_code_id]) stbl.
Proof.
  intros until csz.
  intros GS.
  unfold gen_symb_table in GS. destr_in GS. destruct p. inv GS.
(*   eapply acc_symb_index_in_range; eauto. *)
(* Qed. *)
Admitted.

Lemma reloc_symbentry_exists: forall e dsz csz,
  symbentry_index_in_range (map SecIndex.interp [sec_data_id; sec_code_id]) e ->
  exists e', reloc_symb (reloc_offset_fun dsz csz) e = Some e'.
Proof.
  intros e dsz csz IN.
  red in IN. unfold reloc_symb.
  destruct (symbentry_secindex e); eauto.
  cbn in IN.
  unfold reloc_offset_fun.
  destruct IN as [IN|IN].
  - rewrite IN. destruct N.eq_dec; try congruence. subst.
    eauto.
  - destruct IN as [IN|IN]; try contradiction. subst.
    destruct N.eq_dec. unfold SecIndex.interp in e0. inv e0.
    destruct N.eq_dec; try congruence. subst.
    eauto.
Qed.

Lemma reloc_symbtable_exists_aux : forall stbl f dsz csz,
    symbtable_indexes_in_range (map SecIndex.interp [sec_data_id; sec_code_id]) stbl ->
    f = (reloc_offset_fun dsz csz) ->
    exists stbl', reloc_symbtable f stbl = Some stbl' /\
             Forall2 (fun e1 e2 => reloc_symb f e1 = Some e2) stbl stbl'.
Proof.
  induction stbl as [|e stbl].
  - intros f dsz csz INRNG eq. subst.
    cbn. eexists; eauto.
  - intros f dsz csz INRNG eq. subst.
    inv INRNG.
    generalize (IHstbl _ dsz csz H2 eq_refl).
    destruct 1 as (stbl' & RELOC & INRNG').
    unfold reloc_symbtable.
    cbn. setoid_rewrite RELOC.
    unfold reloc_iter.
    generalize (reloc_symbentry_exists _ dsz csz H1).
    destruct 1 as (e' & RELOC').
    rewrite RELOC'. eexists; split; eauto.
Qed.

Lemma reloc_symbtable_exists: forall stbl f defs d c dsz csz,
    gen_symb_table sec_data_id sec_code_id defs = (stbl, d, c) ->
    f = (reloc_offset_fun dsz csz) ->
    exists stbl', reloc_symbtable f stbl = Some stbl' /\
             Forall2 (fun e1 e2 => reloc_symb f e1 = Some e2) stbl stbl'.
Proof.
  intros. apply reloc_symbtable_exists_aux with dsz csz.
  eapply gen_symb_table_index_in_range; eauto.
  auto.
Qed.

Lemma update_code_data_size_external_size_inv : forall def1 dsz1 csz1 dsz1' csz1',
    is_def_internal is_fundef_internal def1 = false ->
    update_code_data_size dsz1 csz1 def1 = (dsz1', csz1') ->
    dsz1' = dsz1 /\ csz1' = csz1.
Proof.
  intros def1 dsz1 csz1 dsz1' csz1' INT UPDATE.
  destruct def1. destruct g. destruct f.
  - simpl in *. congruence.
  - simpl in *. inv UPDATE. auto.
  - simpl in INT.
    unfold is_var_internal in INT.
    unfold update_code_data_size in UPDATE.
    destruct (gvar_init v).
    + simpl in *. inv UPDATE. auto.
    + destruct i; try (simpl in INT; congruence).
      simpl in INT. destruct l.
      * inv UPDATE. auto.
      * congruence.
  - simpl in *. inv UPDATE. auto.
Qed.

Lemma update_code_data_size_external_ignore_size : forall def1 dsz1 csz1,
    is_def_internal is_fundef_internal def1 = false ->
    update_code_data_size dsz1 csz1 def1 = (dsz1, csz1).
Proof.
  intros def1 dsz1 csz1 INT.
  destruct def1. destruct g.
  destruct f; cbn in INT; try congruence.
  - cbn. auto.
  - cbn in INT.
    unfold update_code_data_size.
    unfold is_var_internal in INT.
    destruct (gvar_init v); cbn in INT; try congruence.
    destruct i; cbn in INT; try congruence.
    destruct l; cbn in INT; try congruence.
  - cbn. auto.
Qed.

Lemma get_extern_symbentry_ignore_size: forall id def dsz1 csz1 dsz2 csz2,
    is_def_internal is_fundef_internal def = false ->
    get_symbentry sec_data_id sec_code_id dsz1 csz1 id def =
    get_symbentry sec_data_id sec_code_id dsz2 csz2 id def.
Proof.
  intros until csz2. intros INT.
  destruct def. destruct g. destruct f.
  - cbn in *. congruence.
  - cbn in *. auto.
  - cbn in *. unfold is_var_internal in INT.
    destruct (gvar_init v); cbn in *; auto.
    destruct i; try congruence.
    destruct l; auto.
    congruence.
  - cbn in *. auto.
Qed.

Lemma acc_symb_partition_extern_intern: forall asf id defs defs1 defs2 rstbl dsz1 csz1 dsz2 csz2,
    asf = acc_symb sec_data_id sec_code_id ->
    partition (fun '(id', _) => ident_eq id' id) defs = (defs1, defs2) ->
    fold_left asf defs ([], dsz1, csz1) = (rstbl, dsz2, csz2) ->
    Forall (fun '(id', def) => is_def_internal is_fundef_internal def = false) defs1 ->
    exists stbl1 stbl2,
      partition (symbentry_id_eq id) (rev rstbl) = (stbl1, stbl2) /\
      fold_left asf defs1 ([], 0, 0) = (rev stbl1, 0, 0) /\
      fold_left asf defs2 ([], dsz1, csz1) = (rev stbl2, dsz2, csz2).
Proof.
  induction defs as [|def defs].
  - intros until csz2.
    intros ASF PART ACC EXT.
    simpl in *. inv PART. inv ACC. simpl.
    eauto.
  - intros until csz2.
    intros ASF PART ACC EXT.
    simpl in *. destr_in PART. destruct def as (id' & def).
    destruct ident_eq; subst.
    + simpl in *. destr_in ACC. inv PART.
      generalize (acc_symb_inv _ _ _ _ eq_refl ACC).
      destruct 1 as (rstbl' & EQ & ACC'). subst.
      inv EXT.
      generalize (IHdefs _ _ _ _ _ _ _ eq_refl eq_refl ACC' H2).
      destruct 1 as (stbl1' & stbl2' & PART' & ACC'' & ACC''').
      rewrite rev_unit. simpl.
      rewrite PART'.
      unfold symbentry_id_eq. rewrite get_symbentry_id.
      rewrite dec_eq_true.
      do 2 eexists; split; auto. 
      generalize (update_code_data_size_external_size_inv _ _ _ H1 Heqp0).
      destruct 1; subst. 
      split; auto.
      generalize (update_code_data_size_external_ignore_size def 0 0 H1).
      intros UPDATE'. rewrite UPDATE'.
      simpl. 
      rewrite (get_extern_symbentry_ignore_size id def dsz1 csz1 0 0); auto.
      apply acc_symb_append_nil. auto.
    + simpl in *. destr_in ACC. inv PART.
      generalize (acc_symb_inv _ _ _ _ eq_refl ACC).
      destruct 1 as (rstbl' & EQ & ACC'). subst.
      generalize (IHdefs _ _ _ _ _ _ _ eq_refl eq_refl ACC' EXT).
      destruct 1 as (stbl1' & stbl2' & PART' & ACC'' & ACC''').
      rewrite rev_unit. simpl.
      rewrite PART'.
      unfold symbentry_id_eq. rewrite get_symbentry_id.
      rewrite dec_eq_false; auto.
      do 2 eexists; split; auto.
      rewrite Heqp0. 
      split; auto.
      apply acc_symb_append_nil. auto.
Qed.
      
      
Definition match_def_symbentry (id_def: ident * option gdef) e :=
  let '(id, def) := id_def in
  exists dsz csz, e = get_symbentry sec_data_id sec_code_id dsz csz id def.
    
Lemma acc_symb_pres_partition: forall asf id defs defs1 defs2 rstbl dsz1 csz1 dsz2 csz2,
    asf = acc_symb sec_data_id sec_code_id ->
    partition (fun '(id', _) => ident_eq id' id) defs = (defs1, defs2) ->
    fold_left asf defs ([], dsz1, csz1) = (rstbl, dsz2, csz2) ->
    exists stbl1 stbl2,
      partition (symbentry_id_eq id) (rev rstbl) = (stbl1, stbl2) /\
      Forall2 match_def_symbentry defs1 stbl1  /\
      Forall2 match_def_symbentry defs2 stbl2.
Proof.
  induction defs as [|def defs].
  - intros until csz2. 
    intros ASF PART ACC.
    simpl in *. inv PART. inv ACC. simpl. eauto.
  - intros until csz2.
    intros ASF PART ACC. subst.
    simpl in *.
    destruct def as (id', def).
    destr_in PART. destr_in ACC.
    generalize (acc_symb_inv _ _ _ _ eq_refl ACC).
    destruct 1 as (rstbl' & EQ & ACC'). subst.
    destruct ident_eq; inv PART; simpl in *.
    + rewrite rev_unit.
      generalize (IHdefs _ _ _ _ _ _ _ eq_refl eq_refl ACC').
      destruct 1 as (stbl1' & stbl2' & PART' & MATCH1 & MATCH2).
      simpl. rewrite PART'.
      unfold symbentry_id_eq. 
      rewrite get_symbentry_id. 
      rewrite dec_eq_true.
      do 2 eexists; split; eauto.
      split; auto.
      constructor; auto.
      red. eauto.
    + rewrite rev_unit.
      generalize (IHdefs _ _ _ _ _ _ _ eq_refl eq_refl ACC').
      destruct 1 as (stbl1' & stbl2' & PART' & MATCH1 & MATCH2).
      simpl. rewrite PART'.
      unfold symbentry_id_eq. 
      rewrite get_symbentry_id. 
      rewrite dec_eq_false; auto.
      do 2 eexists; split; eauto.
      split; auto.
      constructor; auto.
      red. eauto.
Qed.      


Lemma get_symbentry_pres_internal_prop : forall id dsz csz def,
    is_def_internal is_fundef_internal def = 
    is_symbentry_internal (get_symbentry sec_data_id sec_code_id dsz csz id def).
Proof.
  intros. destruct def.
  destruct g. destruct f.
  - cbn. auto.
  - cbn. auto.
  - cbn. unfold is_var_internal. 
    destruct (gvar_init v); cbn; auto.
    destruct i; cbn; auto.
    destruct l; cbn; auto.
  - cbn. auto.
Qed.

Lemma match_def_symbentry_pres_internal_prop : forall id def e,
    match_def_symbentry (id, def) e ->
    is_def_internal is_fundef_internal def = is_symbentry_internal e.
Proof.
  intros id def e MATCH.
  red in MATCH. destruct MATCH as (dsz & csz & SYMB). subst.
  apply get_symbentry_pres_internal_prop.
Qed.



Lemma get_var_entry_type : forall dsz1 csz1 id v,
    symbentry_type (get_symbentry sec_data_id sec_code_id dsz1 csz1 id (Some (Gvar v))) = symb_data.
Proof.
  intros. cbn.
  destruct (gvar_init v); auto.
  destruct i; auto.
  destruct l; auto.
Qed.

Lemma get_fun_entry_type : forall dsz1 csz1 id f,
    symbentry_type (get_symbentry sec_data_id sec_code_id dsz1 csz1 id (Some (Gfun f))) = symb_func.
Proof.
  intros. cbn.
  destruct f; auto.
Qed.

Lemma get_none_entry_type : forall dsz1 csz1 id,
    symbentry_type (get_symbentry sec_data_id sec_code_id dsz1 csz1 id None) = symb_notype.
Proof.
  intros. cbn. auto.
Qed.

Lemma get_none_entry_secindex : forall dsz1 csz1 id,
    symbentry_secindex (get_symbentry sec_data_id sec_code_id dsz1 csz1 id None) = secindex_undef.
Proof.
  intros. cbn. auto.
Qed.

Lemma get_extfun_entry_secindex : forall dsz1 csz1 id f,
    is_fundef_internal f = false 
    -> symbentry_secindex (get_symbentry sec_data_id sec_code_id dsz1 csz1 id (Some (Gfun f))) = secindex_undef.
Proof.
  intros. cbn. auto.
  destruct f.
  cbn in *. congruence.
  simpl. auto.
Qed.

Lemma get_comm_var_entry_secindex:
  forall (dsz1 csz1 : Z) (id : ident) v,
  is_var_comm v = true 
  -> symbentry_secindex
      (get_symbentry sec_data_id sec_code_id dsz1 csz1 id
                         (Some (Gvar v))) = secindex_comm.
Proof.
  intros. subst. cbn. 
  unfold is_var_comm in H.
  destruct (gvar_init v); cbn in H; try congruence.
  cbn. auto.
  destruct i; cbn in H; try congruence.
  destruct l; cbn in H; try congruence.
  cbn. auto.
Qed.

Lemma get_extern_var_entry_secindex:
  forall (dsz1 csz1 : Z) (id : ident) v,
  is_var_extern v = true 
  -> symbentry_secindex
          (get_symbentry sec_data_id sec_code_id dsz1 csz1 id
                         (Some (Gvar v))) = secindex_undef.
Proof.
  intros. subst. cbn. 
  unfold is_var_extern in H.
  destruct (gvar_init v); cbn in H; try congruence.
  cbn. auto.
  destruct i; cbn in H; try congruence.
  destruct l; cbn in H; try congruence.
Qed.


Lemma get_intvar_entry_secindex:
  forall (dsz1 csz1 : Z) (id : ident) v,
  is_var_internal v = true 
  -> symbentry_secindex
          (get_symbentry sec_data_id sec_code_id dsz1 csz1 id
                         (Some (Gvar v))) = 
    (secindex_normal (SecIndex.interp sec_data_id)).
Proof.
  intros. cbn.
  unfold is_var_internal in H.
  destruct (gvar_init v); cbn in H; try congruence.
  destruct i; cbn in *; try congruence.
  destruct l; cbn in *; try congruence.
Qed.


(* Lemma symbentry_secindex_dec : forall e, *)
(*     {symbentry_secindex e = secindex_undef} + *)
(*     {symbentry_secindex e <> secindex_undef}. *)
(* Proof. *)
(*   decide equality. *)
(*   apply N.eq_dec. *)
(* Qed. *)

Lemma update_symbtype_unchanged: forall e t,
    symbentry_type e = t -> update_symbtype e t = e.
Proof.
  intros. destruct e. cbn in *.
  unfold update_symbtype. cbn. rewrite H. auto.
Qed.

Lemma link_get_symbentry_left_some_right_none_comm: forall def id dsz1 dsz2 csz1 csz2,
    link_symb (get_symbentry sec_data_id sec_code_id dsz1 csz1 id (Some def))
              (get_symbentry sec_data_id sec_code_id dsz2 csz2 id None) = 
    Some (get_symbentry sec_data_id sec_code_id dsz1 csz1 id (Some def)).
Proof.
  intros until csz2.
  destruct def. destruct f.
  - cbn. auto.
  - cbn. auto.
  - unfold link_symb.
    rewrite get_var_entry_type.
    rewrite get_none_entry_type.
    replace (link_symbtype symb_data symb_notype) with (Some symb_data) by auto.
    rewrite get_none_entry_secindex.
    destruct (symbentry_secindex
                (get_symbentry sec_data_id sec_code_id dsz1 csz1 id
                               (Some (Gvar v)))); auto.
    f_equal. apply update_symbtype_unchanged.
    apply get_var_entry_type.
Qed.      


Lemma link_get_symbentry_right_none_comm: forall def1 def id dsz1 dsz2 csz1 csz2,
    link_option def1 None = Some def 
    -> link_symb (get_symbentry sec_data_id sec_code_id dsz1 csz1 id def1)
                (get_symbentry sec_data_id sec_code_id dsz2 csz2 id None) = 
      Some (get_symbentry sec_data_id sec_code_id dsz1 csz1 id def).
Proof.
  intros until csz2.
  intros LINK.
  unfold link_option in LINK.
  destruct def1 as [def1|].
  - inv LINK.    
    eapply link_get_symbentry_left_some_right_none_comm; eauto.
  - inv LINK. cbn. auto.
Qed.

Lemma link_get_symbentry_right_extfundef_comm: forall id f1 f2 f dsz1 csz1 dsz2 csz2,
    is_fundef_internal f2 = false
    -> link_fundef f1 f2 = Some f
    -> link_symb
        (get_symbentry sec_data_id sec_code_id dsz1 csz1 id
                       (Some (Gfun f1)))
        (get_symbentry sec_data_id sec_code_id dsz2 csz2 id
                       (Some (Gfun f2))) =
      Some (get_symbentry sec_data_id sec_code_id dsz1 csz1 id
                          (Some (Gfun f))).
Proof.
  intros until csz2.
  intros INT LINK.
  unfold link_symb.
  rewrite get_fun_entry_type.
  rewrite get_fun_entry_type.
  cbn -[get_symbentry].
  rewrite (get_extfun_entry_secindex _ _ _ f2); auto.

  destruct f2; try (cbn in INT; congruence).
  apply link_fundef_inv1 in LINK. subst.
  destr; auto.
  f_equal. apply update_symbtype_unchanged.
  apply get_fun_entry_type.
Qed.

Lemma link_getsymbentry_right_extfun : forall id def1 def f dsz1 csz1 dsz2 csz2,
    is_fundef_internal f = false
    -> link_option def1 (Some (Gfun f)) = Some def
    -> link_symb
        (get_symbentry sec_data_id sec_code_id dsz1 csz1 id def1)
        (get_symbentry sec_data_id sec_code_id dsz2 csz2 id (Some (Gfun f))) =
      Some (get_symbentry sec_data_id sec_code_id dsz1 csz1 id def).
Proof.
  intros until csz2.
  intros INT LINK.
  destruct def1 as [def1|].
  - inv LINK.
    destr_in H0; try congruence. inv H0.
    destruct def1; try (cbn in *; congruence).
    simpl in Heqo. destr_in Heqo; try congruence.
    inv Heqo.
    apply link_get_symbentry_right_extfundef_comm; auto.    
  - inv LINK. 
    unfold link_symb.   
    rewrite get_fun_entry_type.
    rewrite get_none_entry_type.
    replace (link_symbtype symb_notype symb_func) with (Some symb_func) by auto.
    rewrite get_none_entry_secindex.
    rewrite get_extfun_entry_secindex; auto.
    unfold update_symbtype. cbn. 
    destruct f. cbn in *; congruence. auto.
Qed.


Lemma link_get_symbentry_extvars_init_comm :
  forall v1 v2 id dsz1 csz1 dsz2 csz2 (inf:unit) init rd vl,
    is_var_internal v1 = false 
    -> is_var_internal v2 = false 
    -> link_varinit (gvar_init v1) (gvar_init v2) = Some init
    -> link_symb
        (get_symbentry sec_data_id sec_code_id dsz1 csz1 id
                       (Some (Gvar v1)))
        (get_symbentry sec_data_id sec_code_id dsz2 csz2 id
                       (Some (Gvar v2))) =
      Some
        (get_symbentry sec_data_id sec_code_id dsz1 csz1 id
                       (Some (Gvar (mkglobvar inf init rd vl)))).
Proof.
  intros until vl.
  intros INT1 INT2 LINK.
  rewrite var_not_internal_iff in INT1, INT2.
  destruct INT1 as [INT1|INT1]; destruct INT2 as [INT2|INT2].
  - generalize (link_comm_vars_init _ _ INT1 INT2 LINK).
    destruct 1 as (EQ & INIT). subst.
    repeat (rewrite get_comm_var_entry; auto).
    cbn.
    rewrite EQ.
    destruct zeq; try congruence.
  - generalize (link_comm_extern_var_init _ _ INT1 INT2 LINK).
    intros. subst.
    rewrite (get_comm_var_entry _ _ _ _ _ _ INT1).
    rewrite (get_external_var_entry _ _ _ _ _ _ INT2).
    rewrite get_comm_var_entry; auto.
  - generalize (link_extern_comm_var_init _ _ INT1 INT2 LINK).
    intros. subst.
    rewrite (get_comm_var_entry _ _ _ _ _ _ INT2).
    rewrite (get_external_var_entry _ _ _ _ _ _ INT1).
    rewrite get_comm_var_entry; auto.
  - generalize (link_extern_vars_init _ _ INT1 INT2 LINK).
    intros. subst.
    rewrite (get_external_var_entry _ _ _ _ _ _ INT2).
    rewrite (get_external_var_entry _ _ _ _ _ _ INT1).
    rewrite get_external_var_entry; auto.
Qed.    
    

Lemma link_get_symbentry_right_extvar_init_comm :
  forall v1 v2 id dsz1 csz1 dsz2 csz2 (inf:unit) init rd vl,
    is_var_internal v2 = false 
    -> link_varinit (gvar_init v1) (gvar_init v2) = Some init
    -> link_symb
        (get_symbentry sec_data_id sec_code_id dsz1 csz1 id
                       (Some (Gvar v1)))
        (get_symbentry sec_data_id sec_code_id dsz2 csz2 id
                       (Some (Gvar v2))) =
      Some
        (get_symbentry sec_data_id sec_code_id dsz1 csz1 id
                       (Some (Gvar (mkglobvar inf init rd vl)))).
Proof.
  intros until vl.
  intros INT LINK.
  destruct (is_var_internal v1) eqn:INT1.
  generalize INT. intros INT'.
  rewrite var_not_internal_iff in INT.
  destruct INT as [INT|INT].
  - generalize (link_internal_comm_varinit _ _ _ INT1 INT LINK).
    destruct 1 as (IEQ & SEQ & CLS1). subst.
    unfold link_symb.
    repeat rewrite get_var_entry_type.
    cbn -[get_symbentry].
    rewrite get_intvar_entry_secindex; auto.
    rewrite get_comm_var_entry_secindex; auto.
    rewrite get_var_entry_size.
    rewrite get_var_entry_size.
    rewrite SEQ.
    apply dec_eq_true. 
  - unfold link_symb.
    repeat rewrite get_var_entry_type.
    cbn -[get_symbentry].
    rewrite get_intvar_entry_secindex; auto.
    rewrite get_extern_var_entry_secindex; auto.
    generalize (link_internal_external_varinit _ _ _ INT1 INT' LINK).
    destruct 1 as (INITEQ & CLS).
    f_equal. cbn. rewrite INITEQ. auto.
  - apply link_get_symbentry_extvars_init_comm; auto.
Qed.
    

Lemma link_getsymbentry_right_extvar : forall id def1 def v dsz1 csz1 dsz2 csz2,
    is_var_internal v = false
    -> link_option def1 (Some (Gvar v)) = Some def
    -> link_symb
        (get_symbentry sec_data_id sec_code_id dsz1 csz1 id def1)
        (get_symbentry sec_data_id sec_code_id dsz2 csz2 id (Some (Gvar v))) =
      Some (get_symbentry sec_data_id sec_code_id dsz1 csz1 id def).
Proof.
  intros until csz2.
  intros INT LINK.
  destruct def1 as [def1|].
  - inv LINK.
    destr_in H0; try congruence. inv H0.
    destruct def1; try (cbn in *; congruence).
    simpl in Heqo. destr_in Heqo; try congruence.
    inv Heqo.
    unfold link_vardef in Heqo0.
    repeat (destr_in Heqo0; try congruence).
    cbn in Heqo1.
    apply link_get_symbentry_right_extvar_init_comm; auto.
  - inv LINK. 
    unfold link_symb.   
    rewrite get_var_entry_type.
    rewrite get_none_entry_type.
    replace (link_symbtype symb_notype symb_data) with (Some symb_data) by auto.
    rewrite get_none_entry_secindex.
    rewrite var_not_internal_iff in INT. 
    destruct INT as [INT|INT].
    + rewrite get_comm_var_entry_secindex; auto.
      f_equal.
      apply get_extern_symbentry_ignore_size.
      cbn. rewrite var_not_internal_iff. auto.
    + rewrite get_extern_var_entry_secindex; auto.
      f_equal.
      generalize (extern_var_init_nil v INT).
      intros IL. 
      cbn. rewrite IL. 
      unfold update_symbtype. cbn. auto.
Qed.

Lemma link_get_symbentry_comm: forall def1 def2 def id dsz1 dsz2 csz1 csz2,
    is_def_internal is_fundef_internal def2 = false ->
    link_option def1 def2 = Some def 
    -> link_symb (get_symbentry sec_data_id sec_code_id dsz1 csz1 id def1)
                (get_symbentry sec_data_id sec_code_id dsz2 csz2 id def2) = 
      Some (get_symbentry sec_data_id sec_code_id dsz1 csz1 id def).
Proof.
  intros until csz2.
  intros INT LINK.
  destruct def2 as [def2|].
  - cbn in INT. destruct def2.
    + apply link_getsymbentry_right_extfun; auto.
    + apply link_getsymbentry_right_extvar; auto.
  - apply link_get_symbentry_right_none_comm. auto.
Qed.


Lemma link_none_update_code_data_size: forall def1 def dsz1 csz1,
    link_option def1 None = Some def
    -> update_code_data_size dsz1 csz1 def1 = update_code_data_size dsz1 csz1 def.
Proof.
  intros until csz1.
  intros LINK.
  unfold link_option in LINK.
  destruct def1 as [def1|].
  - inv LINK. auto.
  - inv LINK. auto.
Qed.

Lemma link_update_size_extvars_init_comm :
  forall v1 (v2:globvar unit) dsz1 csz1 (inf:unit) init rd vl,
    is_var_internal v1 = false 
    -> is_var_internal v2 = false 
    -> link_varinit (gvar_init v1) (gvar_init v2) = Some init
    -> update_code_data_size dsz1 csz1 (Some (Gvar v1)) =
      update_code_data_size dsz1 csz1
                            (Some (Gvar (mkglobvar inf init rd vl))).
Proof.
  intros until vl.
  intros INT1 INT2 LINK.
  rewrite update_code_data_size_external_ignore_size; auto.
  rewrite update_code_data_size_external_ignore_size; auto.
  cbn.
  generalize (link_external_varinit _ _ _ INT1 INT2 LINK).
  intros.
  unfold is_var_internal. cbn.
  destruct (classify_init init); congruence.
Qed.    


Lemma link_update_size_right_extvar_init_comm :
  forall v1 (v2: globvar unit) dsz1 csz1 (inf:unit) init rd vl,
    is_var_internal v2 = false 
    -> link_varinit (gvar_init v1) (gvar_init v2) = Some init
    -> update_code_data_size dsz1 csz1 (Some (Gvar v1)) =
      update_code_data_size dsz1 csz1 (Some (Gvar (mkglobvar inf init rd vl))).
Proof.
  intros until vl.
  intros INT LINK.
  destruct (is_var_internal v1) eqn:INT1.
  generalize INT. intros INT'.
  rewrite var_not_internal_iff in INT.
  destruct INT as [INT|INT].
  - generalize (link_internal_comm_varinit _ _ _ INT1 INT LINK).
    destruct 1 as (IEQ & SEQ & CLS1). subst.
    auto.
  - generalize (link_internal_external_varinit _ _ _ INT1 INT' LINK).
    destruct 1 as (INITEQ & CLS). subst.
    auto.
  - apply link_update_size_extvars_init_comm with v2; auto.
Qed.


Lemma link_extern_vardef_update_code_data_size: forall def1 v def dsz1 csz1,
        is_var_internal v = false
        -> link_option def1 (Some (Gvar v)) = Some def
        -> update_code_data_size dsz1 csz1 def1 = update_code_data_size dsz1 csz1 def.
Proof.
  intros until csz1.
  intros INT LINK.
  destruct def1 as [def1|].
  - cbn in LINK.
    destr_in LINK; try congruence. inv LINK.
    destruct def1; try (cbn in *; congruence).
    simpl in Heqo. destr_in Heqo; try congruence.
    inv Heqo.
    unfold link_vardef in Heqo0.
    repeat (destr_in Heqo0; try congruence).
    cbn in Heqo1.
    apply link_update_size_right_extvar_init_comm with v; auto.
  - cbn in LINK. inv LINK.
    rewrite (update_code_data_size_external_ignore_size (Some (Gvar v))).
    simpl. auto.
    cbn. auto.
Qed.
  
Lemma link_update_size_right_extfun_comm :
  forall f1 f2 f dsz1 csz1,
    is_fundef_internal f2 = false 
    -> link_fundef f1 f2 = Some f
    -> update_code_data_size dsz1 csz1 (Some (Gfun f1)) =
       update_code_data_size dsz1 csz1 (Some (Gfun f)).
Proof.
  intros until csz1.
  intros INT LINK.
  destruct f2; try (cbn in INT; congruence).
  apply link_fundef_inv1 in LINK. subst.
  auto.
Qed.
  

Lemma link_extern_fundef_update_code_data_size: forall def1 f def dsz1 csz1,
        is_fundef_internal f = false
        -> link_option def1 (Some (Gfun f)) = Some def
        -> update_code_data_size dsz1 csz1 def1 = update_code_data_size dsz1 csz1 def.
Proof.
  intros until csz1.
  intros INT LINK.
  destruct def1 as [def1|].
  - cbn in LINK.
    destr_in LINK; try congruence. inv LINK.
    destruct def1; try (cbn in *; congruence).
    simpl in Heqo. destr_in Heqo; try congruence.
    inv Heqo.
    apply link_update_size_right_extfun_comm with f; auto.    
  - cbn in LINK.  inv LINK.
    rewrite (update_code_data_size_external_ignore_size (Some (Gfun f))).
    simpl. auto.
    cbn. auto.
Qed.


Lemma link_extern_def_update_code_data_size: forall def1 def2 def dsz1 csz1,
    is_def_internal is_fundef_internal def2 = false
    -> link_option def1 def2 = Some def
    -> update_code_data_size dsz1 csz1 def1 = update_code_data_size dsz1 csz1 def.
Proof.
  intros until csz1.
  intros INT LINK.
  destruct def2 as [def2|].
  - cbn in INT. destruct def2.
    + apply link_extern_fundef_update_code_data_size with f; auto.
    + apply link_extern_vardef_update_code_data_size with v; auto.
  - apply link_none_update_code_data_size. auto.
Qed.


(* Lemma link_defs1_acc_symb_comm : forall asf defs1 defs2 defs1_linked defs1_rest defs2_rest rstbl1 rstbl2 dsz1 dsz2 csz1 csz2 dsz1' csz1', *)
(*     asf = acc_symb sec_data_id sec_code_id -> *)
(*     list_norepet (map fst defs2) -> *)
(*     link_defs1 is_fundef_internal defs1 defs2 = Some (defs1_linked, defs1_rest, defs2_rest) -> *)
(*     fold_left asf defs1 ([], dsz1', csz1') = (rstbl1, dsz1, csz1) -> *)
(*     fold_left asf defs2 ([], 0, 0) = (rstbl2, dsz2, csz2) -> *)
(*     exists rstbl1_linked rstbl1_rest rstbl2_rest, *)
(*       link_symbtable1 (rev rstbl1) (rev rstbl2) = Some (rev rstbl1_linked, rev rstbl1_rest, rev rstbl2_rest) /\ *)
(*       fold_left asf defs1_linked ([], dsz1', csz1') = (rstbl1_linked, dsz1, csz1) /\ *)
(*       fold_left asf defs1_rest ([], 0, 0) = (rstbl1_rest, 0, 0) /\ *)
(*       fold_left asf defs2_rest ([], 0, 0) = (rstbl2_rest, dsz2, csz2). *)
(* Proof. *)
(*   induction defs1 as [|def1 defs1]. *)
(*   - intros until csz1'. *)
(*     intros ASF NORPT LINK ACC1 ACC2. *)
(*     simpl in *. inv ACC1. inv LINK. simpl. *)
(*     repeat eexists; auto. *)
(*   - intros until csz1'. *)
(*     intros ASF NORPT LINK ACC1 ACC2.  *)
(*     simpl in *. destruct def1 as (id1 & def1). *)
(*     destruct (link_defs1 is_fundef_internal defs1 defs2) as [r|] eqn:LINK_TAIL; *)
(*       try congruence. *)
(*     destruct r as (p & defs2_rest').  *)
(*     destruct p as (defs1_linked' & defs1_rest'). *)
(*     rewrite ASF in ACC1. simpl in ACC1. *)
(*     destruct (update_code_data_size dsz1' csz1' def1) as (dsz1'' & csz1'') eqn:UPDATE. *)
    
(*     rewrite <- ASF in ACC1. *)
(*     generalize (acc_symb_inv _ _ _ _ ASF ACC1). *)
(*     destruct 1 as (stbl1' & STEQ & ACC1'). *)
(*     generalize (IHdefs1 _ _ _ _ _ _ _ _ _ _ _ _ ASF NORPT LINK_TAIL ACC1' ACC2). *)
(*     destruct 1 as (stbl1_linked & stbl1_rest & stbl2_rest & LINK_SYMB_TAIL & ACC_LINK1 & ACC_REST1 & ACC_REST2). *)
    
(*     destruct (partition (fun '(id', _) => ident_eq id' id1) defs2_rest') as (defs2' & defs2_rest'') eqn:PART. *)
(*     subst rstbl1. rewrite rev_unit. *)
(*     simpl. rewrite LINK_SYMB_TAIL. *)
(*     rewrite get_symbentry_id. *)

(*     destruct defs2' as [|defs2']. *)
(*     + (* No definition with id1 was found in the second module *) *)
(*       generalize (partition_inv_nil1 _ _ PART). intros. subst defs2_rest''. *)
(*       inversion LINK.  *)
(*       subst defs1_linked. subst defs1_rest. subst defs2_rest. *)
(*       generalize (acc_symb_pres_partition _ _ _ _ ASF PART ACC_REST2). *)
(*       destruct 1 as (stbl1 & stbl2 & PART' & MATCH1 & MATCH2). *)
(*       inversion MATCH1; clear MATCH1. subst stbl1. *)
(*       generalize (partition_inv_nil1 _ _ PART'). intros. subst stbl2. *)
(*       rewrite PART'. *)
(*       rewrite <- rev_unit.  *)
(*       do 3 eexists. split. auto. *)
(*       split; auto. subst asf. simpl. rewrite UPDATE. *)
(*       apply acc_symb_append_nil. auto. *)
      
(*     + (* Some definition with id1 was found in the second module *) *)
(*       destruct defs2' as (id, def2). *)
(*       destruct (is_def_internal is_fundef_internal def2) eqn:DEF2_INT. *)
(*       * (* The found definition is internal *) *)
(*         destruct (is_def_internal is_fundef_internal def1) eqn:DEF1_INT; try congruence. *)
(*         inversion LINK; clear LINK. *)
(*         subst defs1_linked'. subst defs1_rest. subst defs2_rest'. *)
(*         generalize (acc_symb_pres_partition _ _ _ _ ASF PART ACC_REST2). *)
(*         destruct 1 as (stbl1 & stbl2 & PART' & MATCH1 & MATCH2). *)
(*         rewrite PART'. inv MATCH1.                 *)
(*         erewrite <- match_def_symbentry_pres_internal_prop; eauto. *)
(*         rewrite DEF2_INT. *)
(*         erewrite <- get_symbentry_pres_internal_prop; eauto. *)
(*         rewrite DEF1_INT. *)
(*         rewrite <- rev_unit. *)
(*         do 3 eexists. split; auto. *)
(*         split; auto. *)
(*         generalize (update_code_data_size_external_size_inv _ _ _ DEF1_INT UPDATE). *)
(*         destruct 1. subst. auto. *)
(*         split; auto. *)
(*         simpl. destr. *)
(*         generalize (update_code_data_size_external_size_inv _ _ _ DEF1_INT Heqp). *)
(*         destruct 1. subst. *)
(*         rewrite (get_extern_symbentry_ignore_size id1 def1 0 0 dsz1' csz1'); auto. *)
(*         apply acc_symb_append_nil. auto. *)

(*       * (* The found definition is external *) *)
(*         destruct (link_option def1 def2) as [def|] eqn:LINKDEF; try congruence. *)
(*         assert (defs2'0 = nil). *)
(*         {  *)
(*           generalize (link_defs_rest_norepet_pres2 _ _ _ _ NORPT LINK_TAIL). *)
(*           intros NORPT'. *)
(*           generalize (lst_norepet_partition_inv _ _ NORPT' PART). *)
(*           destruct 1 as [ DEQ | DEQ ]; try congruence. *)
(*           destruct DEQ as (def2' & DEQ). *)
(*           inv DEQ. auto. *)
(*         }   *)
(*         subst defs2'0. *)
(*         assert (Forall (fun '(_, def) => is_def_internal is_fundef_internal def = false) [(id, def2)]) as DEF2INT'. *)
(*         { constructor. auto. apply Forall_nil. } *)
(*         generalize (acc_symb_partition_extern_intern _ _ _ _ ASF PART ACC_REST2 DEF2INT'). *)
(*         destruct 1 as (stbl2' & stbl2_rest' & PART' & ACC2_REST' & ACC2_REST''). *)
(*         inversion LINK. subst defs1_linked. subst defs1_rest'. subst defs2_rest''. *)
(*         rewrite PART'.  *)
(*         rewrite ASF in ACC2_REST'; simpl in ACC2_REST'. *)
(*         rewrite (update_code_data_size_external_ignore_size def2 0 0) in ACC2_REST'; auto. *)
(*         inversion ACC2_REST'.            *)
(*         symmetry in H0. apply rev_single in H0. subst stbl2'. *)
(*         rewrite <- get_symbentry_pres_internal_prop. rewrite DEF2_INT. *)
(*         (* rewrite DEF2_INT. red in H1. destruct H1 as (dsz & csz & EQ). *) *)
(*         (* subst y.         *) *)
(*         generalize (elements_in_partition_prop _ _ PART'). *)
(*         destruct 1 as (ELEM1 & ELEM2). *)
(*         generalize (ELEM1 _ (in_eq _ _)). *)
(*         unfold symbentry_id_eq. rewrite get_symbentry_id. *)
(*         intros IDEQ. destruct ident_eq; try congruence. subst id1. *)
(*         generalize (link_get_symbentry_comm _ _ id dsz1' 0 csz1' 0 DEF2_INT LINKDEF). *)
(*         intros LINKSYMB. *)
(*         rewrite LINKSYMB. *)
(*         rewrite <- rev_unit. rewrite <- (rev_involutive stbl2_rest'). *)
(*         do 3 eexists; split; auto. *)
(*         split; auto. *)
(*         rewrite ASF. simpl. *)
(*         erewrite <- link_extern_def_update_code_data_size; eauto. *)
(*         rewrite UPDATE. *)
(*         apply acc_symb_append_nil. rewrite ASF in ACC_LINK1. auto. *)
(* Qed. *)
        

(* Lemma link_defs1_gen_symbtbl_comm : forall defs1 defs2 defs1_linked defs1_rest defs2_rest stbl1 stbl2 dsz1 dsz2 csz1 csz2, *)
(*     list_norepet (map fst defs2) -> *)
(*     link_defs1 is_fundef_internal defs1 defs2 = Some (defs1_linked, defs1_rest, defs2_rest) -> *)
(*     gen_symb_table sec_data_id sec_code_id defs1 = (stbl1, dsz1, csz1) -> *)
(*     gen_symb_table sec_data_id sec_code_id defs2 = (stbl2, dsz2, csz2) -> *)
(*     exists stbl1_linked stbl1_rest stbl2_rest, *)
(*       link_symbtable1 stbl1 stbl2 = Some (stbl1_linked, stbl1_rest, stbl2_rest) /\ *)
(*       gen_symb_table sec_data_id sec_code_id defs1_linked = (stbl1_linked, dsz1, csz1) /\ *)
(*       gen_symb_table sec_data_id sec_code_id defs1_rest = (stbl1_rest, 0, 0) /\ *)
(*       gen_symb_table sec_data_id sec_code_id defs2_rest = (stbl2_rest, dsz2, csz2). *)
(* Proof. *)
(*   intros until csz2.  *)
(*   intros NORPT LINK GS1 GS2. unfold gen_symb_table in GS1, GS2. *)
(*   destr_in GS1. destruct p. inv GS1. *)
(*   destr_in GS2. destruct p. inv GS2. *)
(*   generalize (link_defs1_acc_symb_comm _ _ _ _ (@eq_refl _ (acc_symb sec_data_id sec_code_id)) NORPT LINK Heqp Heqp0). *)
(*   destruct 1 as (t1 & t1' & t2 & LINKS & GS1 & GS2 & GS3). *)
(*   unfold gen_symb_table. *)
(*   rewrite LINKS, GS1, GS2, GS3.  *)
(*   repeat eexists; eauto. *)
(* Qed. *)

Lemma partition_reloc_symbtable_comm : forall f l l1 l2 rf l',
    (forall e e', reloc_symb rf e = Some e' -> f e = f e') 
    -> partition f l = (l1, l2)
    -> reloc_symbtable rf l = Some l'
    -> exists l1' l2', partition f l' = (l1', l2') 
                 /\ reloc_symbtable rf l1 = Some l1'
                 /\ reloc_symbtable rf l2 = Some l2'.
Proof.
  induction l as [| e l].
  - intros l1 l2 rf l' PRES PART RELOC.
    cbn in *. inv PART. inv RELOC.
    exists nil, nil.
    split; auto.
  - intros l1 l2 rf l' PRES PART RELOC.
    cbn in *. destr_in PART. destruct (f e) eqn:PEQ.
    + inv PART.
      unfold reloc_iter in RELOC. 
      destr_in RELOC; try congruence.
      destr_in RELOC; try congruence.
      inv RELOC.
      generalize (IHl _ _ _ _ PRES eq_refl Heqo).
      destruct 1 as (l1' & l2' & PART' & RELOC1 & RELOC2).
      exists (s :: l1'), l2'. 
      erewrite PRES in PEQ; eauto.
      cbn. rewrite PEQ. rewrite PART'.
      split; auto.
      split; auto.
      unfold reloc_iter. setoid_rewrite RELOC1.
      rewrite Heqo0. auto.
    + inv PART.
      unfold reloc_iter in RELOC. 
      destr_in RELOC; try congruence.
      destr_in RELOC; try congruence.
      inv RELOC.
      generalize (IHl _ _ _ _ PRES eq_refl Heqo).
      destruct 1 as (l1' & l2' & PART' & RELOC1 & RELOC2).
      exists (l1'), (s ::l2'). 
      erewrite PRES in PEQ; eauto.
      cbn. rewrite PEQ. rewrite PART'.
      split; auto.
      split; auto.
      unfold reloc_iter. setoid_rewrite RELOC2.
      rewrite Heqo0. auto.
Qed.    


Lemma reloc_symb_pres_internal_prop : forall rf s1 s2,
    reloc_symb rf s1 = Some s2 
    -> is_symbentry_internal s1 = is_symbentry_internal s2.
Proof.
  intros rf s1 s2 RELOC.
  unfold reloc_symb in RELOC. 
  unfold is_symbentry_internal.
  destr_in RELOC.
  destr_in RELOC.
  inv RELOC. cbn. auto.
  inv RELOC. rewrite Heqs. auto.
  inv RELOC. rewrite Heqs. auto.
Qed.

Lemma reloc_external_symb : forall rf s,
    is_symbentry_internal s = false
    -> reloc_symb rf s = Some s. 
Proof.
  intros rf s RELOC.
  unfold is_symbentry_internal in RELOC.
  unfold reloc_symb. destr_in RELOC.
Qed.  

Lemma reloc_symb_pres_id: forall rf e e', 
      reloc_symb rf e = Some e' -> symbentry_id e = symbentry_id e'.
Proof.
  intros rf e e' RELOC.
  unfold reloc_symb in RELOC.
  destruct e. cbn in *.
  destruct symbentry_secindex. destruct (rf idx).
  inv RELOC. cbn. auto.
  congruence.
  inv RELOC. cbn. auto.
  inv RELOC. cbn. auto.
Qed.

Lemma reloc_symb_pres_type: forall rf e e', 
      reloc_symb rf e = Some e' -> symbentry_type e = symbentry_type e'.
Proof.
  intros rf e e' RELOC.
  unfold reloc_symb in RELOC.
  destruct e. cbn in *.
  destruct symbentry_secindex. destruct (rf idx).
  inv RELOC. cbn. auto.
  congruence.
  inv RELOC. cbn. auto.
  inv RELOC. cbn. auto.
Qed.

Lemma reloc_symb_pres_secindex: forall rf e e', 
      reloc_symb rf e = Some e' -> symbentry_secindex e = symbentry_secindex e'.
Proof.
  intros rf e e' RELOC.
  unfold reloc_symb in RELOC.
  destruct e. cbn in *.
  destruct symbentry_secindex. destruct (rf idx).
  inv RELOC. cbn. auto.
  congruence.
  inv RELOC. cbn. auto.
  inv RELOC. cbn. auto.
Qed.

Lemma reloc_symb_pres_size: forall rf e e', 
      reloc_symb rf e = Some e' -> symbentry_size e = symbentry_size e'.
Proof.
  intros rf e e' RELOC.
  unfold reloc_symb in RELOC.
  destruct e. cbn in *.
  destruct symbentry_secindex. destruct (rf idx).
  inv RELOC. cbn. auto.
  congruence.
  inv RELOC. cbn. auto.
  inv RELOC. cbn. auto.
Qed.

Lemma reloc_symb_pres_update_symbtype : forall rf e e' t,
    reloc_symb rf e = Some e' ->
    reloc_symb rf (update_symbtype e t) = Some (update_symbtype e' t).
Proof.
  intros rf e e' t RELOC.
  destruct e. unfold reloc_symb in *. cbn in *.
  destr_in RELOC; try congruence; subst.
  destr_in RELOC; try congruence.
  inv RELOC. auto.
Qed.



Lemma reloc_symb_id_eq: forall id rf e e', 
      reloc_symb rf e = Some e' -> symbentry_id_eq id e = symbentry_id_eq id e'.
Proof.
  intros.
  unfold symbentry_id_eq.
  erewrite reloc_symb_pres_id; eauto.
Qed.

(* Lemma reloc_link_symbtable_comm2: forall rf stbl1 stbl2 stbl2' stbl1_linked stbl1_rest stbl2_rest, *)
(*     reloc_symbtable rf stbl2 = Some stbl2' -> *)
(*     link_symbtable1 stbl1 stbl2 = Some (stbl1_linked, stbl1_rest, stbl2_rest) -> *)
(*     exists stbl2_rest', reloc_symbtable rf stbl2_rest = Some stbl2_rest' /\ *)
(*                    link_symbtable1 stbl1 stbl2' = Some (stbl1_linked, stbl1_rest, stbl2_rest'). *)
(* Proof. *)
(*   induction stbl1 as [|e stbl1]. *)
(*   - intros until stbl2_rest. *)
(*     intros RELOC LINK. cbn in *. inv LINK. *)
(*     eauto. *)
(*   - intros until stbl2_rest. *)
(*     intros RELOC LINK. cbn in *. *)
(*     destr_in LINK; try congruence. destruct p. destruct p. *)
(*     destr_in LINK; try congruence. destr_in LINK.  *)
(*     generalize (IHstbl1 _ _ _ _ _ RELOC Heqo). *)
(*     destruct 1 as (stbl2_rest' & RELOC' & LINK'). *)
(*     destruct l. *)
(*     + inv LINK. generalize (partition_inv_nil1 _ _ Heqp). intros. subst l0. *)
(*       exists stbl2_rest'; split; auto. *)
(*       rewrite LINK'.       *)
(*       generalize (partition_reloc_symbtable_comm _ _ _ (reloc_symb_id_eq i rf) Heqp RELOC'). *)
(*       destruct 1 as (l1' & l2' & PART & RELOC1 & RELOC2). *)
(*       cbn in RELOC1. inv RELOC1. *)
(*       generalize (partition_inv_nil1 _ _ PART). intros. subst l2'. *)
(*       rewrite PART. auto. *)
(*     + destr_in LINK. *)
(*       * destr_in LINK; try congruence. *)
(*         inv LINK. *)
(*         exists stbl2_rest'. split; auto. *)
(*         rewrite LINK'.  *)
(*         generalize (partition_reloc_symbtable_comm _ _ _ (reloc_symb_id_eq i rf) Heqp RELOC'). *)
(*         destruct 1 as (l1' & l2' & PART & RELOC1 & RELOC2). *)
(*         rewrite PART. cbn in RELOC1. *)
(*         unfold reloc_iter in RELOC1. *)
(*         destr_in RELOC1; try congruence. *)
(*         destr_in RELOC1; try congruence. *)
(*         inv RELOC1. *)
(*         erewrite <- reloc_symb_pres_internal_prop; eauto. *)
(*         rewrite Heqb. auto. *)
(*       * destr_in LINK; try congruence. *)
(*         inv LINK. *)
(*         rewrite LINK'. *)
(*         generalize (partition_reloc_symbtable_comm _ _ _ (reloc_symb_id_eq i rf) Heqp RELOC'). *)
(*         destruct 1 as (l1' & l2' & PART & RELOC1 & RELOC2). *)
(*         rewrite RELOC2. eexists; split; eauto. *)
(*         rewrite PART. *)
(*         cbn in RELOC1. unfold reloc_iter in RELOC1. *)
(*         destr_in RELOC1; try congruence. *)
(*         destr_in RELOC1; try congruence. inv RELOC1. *)
(*         erewrite <- reloc_symb_pres_internal_prop; eauto. *)
(*         rewrite Heqb.          *)
(*         erewrite reloc_external_symb in Heqo3; eauto. inv Heqo3. *)
(*         rewrite Heqo1. auto. *)
(* Qed. *)
  

(* Lemma reloc_link_symb_comm : forall e1 e2 e e1' rf, *)
(*     is_symbentry_internal e2 = false  *)
(*     -> reloc_symb rf e1 = Some e1' *)
(*     -> link_symb e1 e2 = Some e *)
(*     -> exists e', reloc_symb rf e = Some e' /\ link_symb e1' e2 = Some e'. *)
(* Proof. *)
(*   intros e1 e2 e e1' rf INT RELOC LINK. *)
(*   unfold link_symb in *. *)
(*   erewrite <- reloc_symb_pres_type; eauto. *)
(*   erewrite <- reloc_symb_pres_secindex; eauto. *)
(*   erewrite <- reloc_symb_pres_size; eauto. *)
(*   destr_in LINK; try congruence. *)
(*   destr_in LINK. *)
(*   - destr_in LINK; try congruence. *)
(*     + destruct zeq; try congruence. inv LINK. *)
(*       rewrite RELOC. eexists; split; eauto. *)
(*     + inv LINK. eauto. *)
(*   - destr_in LINK; try congruence. *)
(*     + destruct zeq; try congruence. inv LINK. *)
(*       exists e; split; auto. *)
(*       apply reloc_external_symb; auto. *)
(*     + destruct zeq; try congruence. inv LINK. *)
(*       rewrite RELOC. eexists; split; eauto.  *)
(*     + inv LINK. rewrite RELOC. eexists; split; eauto.  *)
(*   - destr_in LINK; try congruence. *)
(*     + inv LINK. *)
(*       exists e; split; auto. *)
(*       apply reloc_external_symb; auto. *)
(*     + inv LINK. exists e; split; auto. *)
(*       apply reloc_external_symb; auto. *)
(*     + inv LINK.  *)
(*       eexists; split; eauto.      *)
(*       apply reloc_symb_pres_update_symbtype; auto. *)
(* Qed. *)


(* Lemma reloc_link_symbtable_comm1: forall rf stbl1 stbl2 stbl1' stbl1_linked stbl1_rest stbl2_rest, *)
(*     reloc_symbtable rf stbl1 = Some stbl1' -> *)
(*     link_symbtable1 stbl1 stbl2 = Some (stbl1_linked, stbl1_rest, stbl2_rest) -> *)
(*     exists stbl1_linked', reloc_symbtable rf stbl1_linked = Some stbl1_linked' /\ *)
(*                      link_symbtable1 stbl1' stbl2 = Some (stbl1_linked', stbl1_rest, stbl2_rest). *)
(* Proof. *)
(*     induction stbl1 as [|e stbl1]. *)
(*   - intros until stbl2_rest. *)
(*     intros RELOC LINK. cbn in *. inv RELOC. inv LINK. *)
(*     exists nil. split; auto. *)
(*   - intros until stbl2_rest. *)
(*     intros RELOC LINK. cbn in *. *)
(*     unfold reloc_iter in RELOC. *)
(*     destr_in RELOC; try congruence. *)
(*     destr_in RELOC; try congruence. inv RELOC. *)
(*     destr_in LINK; try congruence. destruct p. destruct p. *)
(*     destr_in LINK; try congruence. destr_in LINK.  *)
(*     generalize (IHstbl1 _ _ _ _ _ Heqo Heqo1). *)
(*     destruct 1 as (stbl1_rest' & RELOC' & LINK'). *)
(*     destruct l0. *)
(*     + inv LINK. generalize (partition_inv_nil1 _ _ Heqp). intros. subst l1. *)
(*       exists (s :: stbl1_rest'); split; auto. *)
(*       cbn. unfold reloc_iter. *)
(*       setoid_rewrite RELOC'. rewrite Heqo0. auto. *)
(*       cbn. rewrite LINK'.  *)
(*       erewrite <- reloc_symb_pres_id; eauto. rewrite Heqo2. *)
(*       rewrite Heqp. auto. *)
(*     + destr_in LINK. *)
(*       * destr_in LINK; try congruence. *)
(*         inv LINK. *)
(*         exists stbl1_rest'. split; auto. *)
(*         cbn. *)
(*         rewrite LINK'.  *)
(*         erewrite <- reloc_symb_pres_id; eauto. rewrite Heqo2. *)
(*         rewrite Heqp. rewrite Heqb.  *)
(*         erewrite <- reloc_symb_pres_internal_prop; eauto. rewrite Heqb0. *)
(*         erewrite reloc_external_symb in Heqo0; eauto. inv Heqo0. *)
(*         auto. *)
(*       * destr_in LINK; try congruence. *)
(*         inv LINK. *)
(*         generalize (reloc_link_symb_comm _ _ _ Heqb Heqo0 Heqo3). *)
(*         destruct 1 as (e' & RELOCS & LINKS). *)
(*         exists (e' :: stbl1_rest'). split. *)
(*         ** cbn. unfold reloc_iter. *)
(*            setoid_rewrite RELOC'. rewrite RELOCS. auto. *)
(*         ** cbn. *)
(*            rewrite LINK'.  *)
(*            erewrite <- reloc_symb_pres_id; eauto. rewrite Heqo2. *)
(*            rewrite Heqp. rewrite Heqb. rewrite LINKS. *)
(*            auto. *)
(* Qed. *)

Lemma update_size_offset : forall def dsz csz dsz1 csz1 dofs cofs,
    update_code_data_size dsz csz def = (dsz1, csz1) ->
    update_code_data_size (dofs + dsz) (cofs + csz) def = (dofs + dsz1, cofs + csz1).
Proof.
  intros until cofs. intros UPDATE.
  destruct def. destruct g. destruct f.
  - cbn in *. inv UPDATE. f_equal; omega.
  - cbn in *. inv UPDATE. f_equal; omega.
  - unfold update_code_data_size in *.
    destr_in UPDATE. 
    destruct i; try (inv UPDATE; cbn; f_equal; omega).
    destruct l; try (inv UPDATE; cbn; f_equal; omega).
  - cbn in *. inv UPDATE. auto.
Qed.

Lemma reloc_get_symbentry : forall dofs cofs dsz csz id def e,
    reloc_symb (reloc_offset_fun dofs cofs) (get_symbentry sec_data_id sec_code_id dsz csz id def) = Some e
    -> e = (get_symbentry sec_data_id sec_code_id (dsz + dofs) (csz + cofs) id def).
Proof.
  intros until e. intro RELOC.
  destruct def. destruct g. destruct f.
  - cbn in *. inv RELOC. f_equal.
  - cbn in *. inv RELOC. auto.
  - cbn in *. destr_in RELOC. cbn in *. inv RELOC. auto.
    destruct i; cbn in *; try congruence.
    destruct l; cbn in *; try congruence.
  - cbn in *. inv RELOC. auto.
Qed.

Lemma acc_symb_reloc: forall asf defs stbl stbl' dsz1 dsz2 csz1 csz2 dofs cofs,
    asf = (acc_symb sec_data_id sec_code_id) 
    -> fold_left asf defs ([], dsz1, csz1) = (stbl, dsz2, csz2)
    -> reloc_symbtable (reloc_offset_fun dofs cofs) (rev stbl) = Some stbl'
    -> fold_left asf defs ([], dofs + dsz1, cofs + csz1) = (rev stbl', dofs + dsz2, cofs + csz2).
Proof.
  induction defs as [|def defs].
  - intros until cofs. intros ASF ACC RELOC.
    cbn in *. inv ACC. cbn in RELOC. inv RELOC. auto.
  - intros until cofs. intros ASF ACC RELOC.
    subst. cbn in *. destruct def as [id def].
    destr_in ACC.
    generalize (acc_symb_inv _ _ _ _ eq_refl ACC).
    destruct 1 as (stbl1 & EQ & ACC1). subst.    
    erewrite update_size_offset; eauto.
    rewrite rev_unit in RELOC.
    cbn in RELOC. unfold reloc_iter in RELOC.
    destr_in RELOC; try congruence.
    destr_in RELOC; try congruence.
    inv RELOC.
    generalize (IHdefs _ _ _ _ _ _ _ _ eq_refl ACC1 Heqo).
    intros ACC'.
    generalize (acc_symb_append_nil _ _ _ _ _ 
                                    [get_symbentry sec_data_id sec_code_id (dofs + dsz1) (cofs + csz1) id def] ACC').
    intros ACC''. setoid_rewrite ACC''.
    cbn. f_equal. f_equal.
    apply reloc_get_symbentry in Heqo0. subst. 
    f_equal. f_equal. f_equal; omega.
Qed.    


Lemma acc_symb_reloc_comm: forall asf defs1 defs2 stbl1 stbl2 stbl2'
                             dsz1 dsz2 csz1 csz2 dsz1' csz1',
    asf = (acc_symb sec_data_id sec_code_id) 
    -> fold_left asf defs1 ([], dsz1, csz1) = (stbl1, dsz1', csz1')
    -> fold_left asf defs2 ([], 0, 0) = (stbl2, dsz2, csz2)
    -> reloc_symbtable (reloc_offset_fun dsz1' csz1') (rev stbl2) = Some stbl2'
    -> fold_left asf (defs1 ++ defs2) ([], dsz1, csz1) = ((rev stbl2') ++ stbl1, dsz1' + dsz2, csz1' + csz2).
Proof.
  induction defs1.
  - intros until csz1'.
    intros ASF ACC1 ACC2 RELOC.
    cbn in *. inv ACC1.
    rewrite app_nil_r.
    replace ([], dsz1', csz1') with (@nil symbentry, dsz1'+0, csz1'+0).
    eapply acc_symb_reloc; eauto.
    f_equal. f_equal. omega. omega.
  - intros until csz1'.
    intros ASF ACC1 ACC2 RELOC.
    cbn in *. rewrite ASF in ACC1. unfold acc_symb in ACC1.
    destruct a as [id def]. destr_in ACC1.
    generalize (acc_symb_inv _ _ _ _ eq_refl ACC1).
    destruct 1 as (stbl1' & SEQ & ACC1'). subst.
    generalize (IHdefs1 _ _ _ _ _ _ _ _ _ _ eq_refl ACC1' ACC2 RELOC).
    intros ACC'.
    unfold acc_symb. rewrite Heqp. 
    setoid_rewrite acc_symb_append_nil; eauto.
    rewrite app_assoc. auto.
Qed.
  

Lemma gen_symb_table_reloc_comm : forall defs1 defs2 stbl1 stbl2 stbl2' dsz1 dsz2 csz1 csz2,
    gen_symb_table sec_data_id sec_code_id defs1 = (stbl1, dsz1, csz1) ->
    gen_symb_table sec_data_id sec_code_id defs2 = (stbl2, dsz2, csz2) ->
    reloc_symbtable (reloc_offset_fun dsz1 csz1) stbl2 = Some stbl2' ->
    gen_symb_table sec_data_id sec_code_id (defs1 ++ defs2) = (stbl1 ++ stbl2', dsz1 + dsz2, csz1 + csz2).
Proof.
  intros until csz2.
  intros GS1 GS2 RELOC.
  unfold gen_symb_table in GS1, GS2.
  destr_in GS1; inv GS1.
  destr_in GS2; inv GS2.
  destruct p, p0. inv H0. inv H1.
  unfold gen_symb_table.  
Admitted.
(*   erewrite acc_symb_reloc_comm; eauto. *)
(*   rewrite rev_app_distr. rewrite rev_involutive. *)
(*   auto. *)
(* Qed. *)


(* Lemma link_gen_symb_comm : forall defs1 defs2 defs stbl1 stbl2 dsz1 csz1 dsz2 csz2 f_ofs, *)
(*     list_norepet (map fst defs1) -> *)
(*     list_norepet (map fst defs2) -> *)
(*     link_defs is_fundef_internal defs1 defs2 = Some defs -> *)
(*     gen_symb_table sec_data_id sec_code_id defs1 = (stbl1, dsz1, csz1) -> *)
(*     gen_symb_table sec_data_id sec_code_id defs2 = (stbl2, dsz2, csz2) -> *)
(*     f_ofs = reloc_offset_fun dsz1 csz1 -> *)
(*     exists stbl stbl2', *)
(*       reloc_symbtable f_ofs stbl2 = Some stbl2' /\ *)
(*       link_symbtable stbl1 stbl2' = Some stbl *)
(*       /\ gen_symb_table sec_data_id sec_code_id defs = (stbl, dsz1 + dsz2, csz1 + csz2). *)
(* Proof. *)
(*   intros defs1 defs2 defs stbl1 stbl2 dsz1 csz1 dsz2 csz2 f_ofs NORPT1 NORPT2 LINK GS1 GS2 FOFS. *)

(*   unfold link_defs in LINK. *)
(*   destruct (link_defs1 is_fundef_internal defs1 defs2) as [r|] eqn:LINKDEFS1;  *)
(*     try congruence. *)
(*   destruct r as (p & defs2_rest). destruct p as (defs1_linked, defs1_rest). *)
(*   destruct (link_defs1 is_fundef_internal defs2_rest defs1_rest) as [r|] eqn:LINKDEFS2;  *)
(*     try congruence. *)
(*   destruct r. destruct p as (defs2_linked & r). inv LINK. *)

(*   generalize (link_defs1_gen_symbtbl_comm _ _ NORPT2 LINKDEFS1 GS1 GS2). *)
(*   destruct 1 as (stbl1_linked & stlb1_rest & stbl2_rest & LINKSTBL1 & GSLINKED1 & GSREST1 & GSREST2). *)
(*   generalize (reloc_symbtable_exists _ GS2 (@eq_refl _ (reloc_offset_fun dsz1 csz1))). *)
(*   destruct 1 as (stbl2' & RELOC & RELOC_PROP). *)
(*   generalize (reloc_link_symbtable_comm2 _ _ _ RELOC LINKSTBL1). *)
(*   destruct 1 as (stbl2_rest' & RELOC2' & LINKSTBL1').   *)
(*   generalize (link_defs_rest_norepet_pres1 _ _ _ _ NORPT1 LINKDEFS1). *)
(*   intros NORPT1'. *)
(*   generalize (link_defs1_gen_symbtbl_comm _ _ NORPT1' LINKDEFS2 GSREST2 GSREST1). *)
(*   destruct 1 as (stbl_linked2 & sr1 & sr2 & LINKSTBL2 & GSLINKED2 & GS3 & GS4). *)
(*   generalize (reloc_link_symbtable_comm1 _ _ _ RELOC2' LINKSTBL2). *)
(*   destruct 1 as (stbl2_linked' & RELOC2 & LINKREST2). *)

(*   unfold link_symbtable. *)
(*   eexists. exists stbl2'. split; auto. *)
(*   rewrite LINKSTBL1'. *)
(*   rewrite LINKREST2. split; auto.   *)
(*   eapply gen_symb_table_reloc_comm; eauto. *)
(* Qed. *)


(** ** Commutativity of linking and section generation *)

Class PERWithFun (A:Type) (aeq:A -> A -> Prop) `{PER A aeq} (f:A -> bool) :=
{
  eq_imply_fun_true: forall e1 e2, aeq e1 e2 -> f e1 = true /\ f e2 = true;
  (** Equality between elements in a restricted domain *)
  fun_true_imply_eq: forall e, f e = true -> aeq e e;
}.

Section WithEquivAndFun.

Context `{PERWithFun}.

Inductive list_in_order : list A -> list A -> Prop :=
| lorder_nil : list_in_order nil nil
| lorder_left_false : forall e l1 l2, 
    f e = false -> list_in_order l1 l2 -> list_in_order (e :: l1) l2
| lorder_right_false : forall e l1 l2,
    f e = false -> list_in_order l1 l2 -> list_in_order l1 (e :: l2)
| lorder_true : forall e1 e2 l1 l2,
    aeq e1 e2 -> list_in_order l1 l2 -> list_in_order (e1::l1) (e2::l2).

Lemma list_in_order_false_inv : forall (l1' l1 l2: list A) e,
    f e = false -> l1' = (e :: l1) -> list_in_order l1' l2 -> list_in_order l1 l2.
Proof.
  induction 3. 
  - inv H2.
  - inv H2. auto.
  - apply lorder_right_false; auto.
  - subst. inv H2. apply eq_imply_fun_true in H3. destruct H3.
    congruence.
Qed.

Lemma list_in_order_true_inv : forall (l1' l1 l2: list A)  e1,
    f e1 = true -> l1' = (e1 :: l1) -> list_in_order l1' l2 -> 
    exists l3 l4 e2, l2 = l3 ++ (e2 :: l4) /\ 
             aeq e1 e2 /\
             Forall (fun e' => f e' = false) l3 /\
             list_in_order l1 l4.
Proof.
  induction 3.
  - inv H2.
  - inv H2. congruence.
  - subst. 
    generalize (IHlist_in_order eq_refl).
    destruct 1 as (l3 & l4 & e2 & EQ & EEQ & FP & ORDER). subst.
    exists (e :: l3), l4, e2. split.
    rewrite <- app_comm_cons. auto. split; auto.
  - inv H2. exists nil, l2, e2. split. auto.
    split; auto.
Qed.

Lemma list_in_order_right_false_list : forall (l2' l1 l2: list A),
    Forall (fun e : A => f e = false) l2' ->
    list_in_order l1 l2 -> 
    list_in_order l1 (l2' ++ l2).
Proof.
  induction l2'.
  - intros l1 l2 FALL ORDER. simpl. auto.
  - intros l1 l2 FALL ORDER. simpl. 
    generalize (Forall_inv FALL).
    intros FLS.
    apply lorder_right_false; auto.
    apply IHl2'; auto.
    rewrite Forall_forall in *.
    intros. apply FALL. apply in_cons. auto.
Qed.


Lemma list_in_order_trans : forall (l1 l2 l3: list A),
    list_in_order l1 l2 -> list_in_order l2 l3 -> list_in_order l1 l3.
Proof.
  intros l1 l2 l3 ORDER.
  generalize l3.
  induction ORDER.
  - auto.
  - intros l0 ORDER1. constructor; auto.
  - intros l0 ORDER1. 
    generalize (list_in_order_false_inv H1 (eq_refl (e::l2)) ORDER1). auto.
  - intros l0 ORDER1.
    generalize (eq_imply_fun_true _ _ H1). destruct 1 as (FEQ1 & FEQ2).
    generalize (list_in_order_true_inv FEQ2 (eq_refl (e2::l2)) ORDER1).
    destruct 1 as (l2' & l2'' & e3 & EQ & EEQ & ALL & ORDER2).
    subst.
    apply IHORDER in ORDER2.
    apply list_in_order_right_false_list; auto.
    apply lorder_true; auto.
    apply PER_Transitive with e2; auto.
Qed.    

Lemma list_in_order_cons : forall (l1 l2:list A) e,
    list_in_order l1 l2 -> list_in_order (e::l1) (e::l2).
Proof.
  intros l1 l2 e ORDER.
  destruct (f e) eqn:EQ.
  - apply lorder_true; auto.
    apply fun_true_imply_eq. auto.
  - apply lorder_left_false; auto.
    apply lorder_right_false; auto.
Qed.

Lemma list_in_order_refl: forall (l:list A),
    list_in_order l l.
Proof.
  induction l; intros.
  - apply lorder_nil.
  - apply list_in_order_cons. auto.
Qed.

Lemma partition_pres_list_in_order: forall pf (l l1 l2: list A),
    partition pf l = (l1, l2) ->
    Forall (fun e => f e = false) l1 ->
    list_in_order l l2.
Proof.
  induction l.
  - intros l1 l2 PART ALL. simpl in *. inv PART. constructor.
  - intros l1 l2 PART ALL. simpl in *.
    destruct (pf a).
    + destruct (partition pf l) eqn:PART1. inv PART.
      apply lorder_left_false. 
      apply Forall_inv in ALL. auto.
      apply IHl with l0; auto.
      rewrite Forall_forall in *. intros. 
      apply ALL; auto. apply in_cons. auto.
    + destruct (partition pf l) eqn:PART1. inv PART.
      apply list_in_order_cons. 
      apply IHl with l1; auto.
Qed.

End WithEquivAndFun.

Arguments list_in_order [A] _ _ _ _.


Section WithFunVar.

Context {F V:Type}.

(** Equality between internal definitions *)
Definition def_internal (def: option (AST.globdef (AST.fundef F) V)) :=
  is_def_internal is_fundef_internal def.

Inductive def_eq : 
  option (AST.globdef (AST.fundef F) V) -> option (AST.globdef (AST.fundef F) V) -> Prop :=
| fundef_eq : forall f, is_fundef_internal f = true -> def_eq (Some (Gfun f)) (Some (Gfun f))
| vardef_eq : forall v1 v2, 
    is_var_internal v1 = true -> is_var_internal v2 = true ->
    gvar_init v1 = gvar_init v2 -> def_eq (Some (Gvar v1)) (Some (Gvar v2)).
  
Lemma def_eq_symm : forall f1 f2, def_eq f1 f2 -> def_eq f2 f1.
Proof.
  intros. inv H.
  - constructor. auto.
  - econstructor; eauto.
Qed.

Lemma def_eq_trans: forall f1 f2 f3, 
    def_eq f1 f2 -> def_eq f2 f3 -> def_eq f1 f3.
Proof.
  intros f1 f2 f3 EQ1 EQ2. inv EQ1. 
  - inv EQ2. constructor. auto.
  - inv EQ2. econstructor; eauto.
    eapply eq_trans; eauto.
Qed.

Lemma def_eq_imply_internal : forall f1 f2,
    def_eq f1 f2 -> def_internal f1 = true /\ def_internal f2 = true.
Proof.
  intros f1 f2 EQ.
  inv EQ.
  - simpl. auto.
  - simpl in *. auto.
Qed.

Lemma def_internal_imply_eq : 
  forall f, def_internal f = true -> def_eq f f.
Proof.
  intros f INT.
  destruct f. destruct g.
  - constructor; auto.
  - simpl in *. constructor; auto.
  - simpl in *. congruence.
Qed.

Instance PERDefEq : PER def_eq :=
{
  PER_Symmetric := def_eq_symm;
  PER_Transitive := def_eq_trans;
}.

Instance DefEq : PERWithFun def_internal :=
{
  eq_imply_fun_true := def_eq_imply_internal;
  fun_true_imply_eq := def_internal_imply_eq;
}.

(** Equality between id and internal definition pairs *)
Definition id_def_internal (iddef: ident * option (AST.globdef (AST.fundef F) V)) :=
  let '(id, def) := iddef in
  def_internal def.

Definition id_def_eq (iddef1 iddef2: ident * option (AST.globdef (AST.fundef F) V)) : Prop :=
  let '(id1, def1) := iddef1 in
  let '(id2, def2) := iddef2 in
  id1 = id2 /\ def_eq def1 def2.

Lemma id_def_eq_symm : forall f1 f2, id_def_eq f1 f2 -> id_def_eq f2 f1.
Proof.
  intros. unfold id_def_eq in *.
  destruct f1, f2. destruct H. split; auto.
  apply def_eq_symm; auto.
Qed.

Lemma id_def_eq_trans: forall f1 f2 f3, 
    id_def_eq f1 f2 -> id_def_eq f2 f3 -> id_def_eq f1 f3.
Proof.
  intros f1 f2 f3 EQ1 EQ2. 
  unfold id_def_eq in *. destruct f1, f2, f3.
  destruct EQ1, EQ2. split.
  eapply eq_trans; eauto.
  eapply def_eq_trans; eauto.
Qed.

Lemma id_def_eq_imply_internal : forall f1 f2,
    id_def_eq f1 f2 -> id_def_internal f1 = true /\ id_def_internal f2 = true.
Proof.
  intros f1 f2 EQ.
  unfold id_def_eq in EQ.
  destruct f1, f2. destruct EQ. subst.
  simpl. 
  apply def_eq_imply_internal; eauto.
Qed.

Lemma id_def_interal_imply_eq : 
  forall f, id_def_internal f = true -> id_def_eq f f.
Proof.
  intros f INT.
  destruct f. destruct o. destruct g.
  - simpl. split; auto. constructor; auto.
  - simpl in *. split; auto. constructor; auto.
  - simpl in *. split; auto. congruence.
Qed.

Instance PERIdDefEq : PER id_def_eq :=
{
  PER_Symmetric := id_def_eq_symm;
  PER_Transitive := id_def_eq_trans;
}.

Instance IdDefEq : PERWithFun id_def_internal :=
{
  eq_imply_fun_true := id_def_eq_imply_internal;
  fun_true_imply_eq := id_def_interal_imply_eq;
}.


Lemma link_external_defs : forall {LV: Linker V} (def1 def2 def: option (globdef (AST.fundef F) V)),
    def_internal def1 = false ->
    def_internal def2 = false ->
    link_option def1 def2 = Some def ->
    def_internal def = false.
Proof.
  intros LV def1 def2 def INT1 INT2 LINK.
  unfold link_option in LINK.
  destruct def1, def2.
  - 
    destruct (link g g0) eqn:LINKG; try congruence. inv LINK.
    unfold link in LINKG.
    Transparent Linker_def.
    unfold Linker_def in LINKG.
    unfold link_def in LINKG.
    destruct g, g0.
    + destruct (link f f0) eqn:LINKF; try congruence. inv LINKG.
      unfold link in LINKF.
      Transparent Linker_fundef.
      unfold Linker_fundef in LINKF.
      simpl in *.
      apply link_external_fundefs with f f0; eauto.
    + congruence.
    + congruence.
    + destruct (link v v0) eqn:LINKV; try congruence. inv LINKG.
      simpl in *.     
      apply link_external_vars with _ v v0; eauto.
  - inv LINK. auto.
  - inv LINK. auto.
  - inv LINK. auto.
Qed.    
  

Lemma link_internal_external_defs : forall {LV: Linker V} (def1 def2 def: option (globdef (AST.fundef F) V)),
    def_internal def1 = true ->
    def_internal def2 = false ->
    link_option def1 def2 = Some def ->
    def_eq def def1.
Proof.
  intros LV def1 def2 def INT1 INT2 LINK.
  unfold link_option in LINK.
  destruct def1, def2.
  - destr_in LINK. inv LINK. simpl in *.
    destruct g, g0; simpl in *; try congruence.
    + destr_in Heqo. inv Heqo.
      generalize (link_extern_fundef_inv _ _ INT2 Heqo0). 
      intros. subst. constructor. auto.
    + destr_in Heqo. inv Heqo.
      generalize (link_internal_external_vars _ _ _ INT1 INT2 Heqo0).
      destruct 1.
      constructor; auto.
  - inv LINK. apply def_internal_imply_eq; auto.
  - simpl in *. congruence.
  - simpl in *. congruence.
Qed.  


  
(* Lemma link_defs1_in_order : forall {LV: Linker V} defs1 defs2 defs1_linked defs1_rest defs2_rest, *)
(*     list_norepet (map fst defs2) -> *)
(*     link_defs1 is_fundef_internal defs1 defs2 = Some (defs1_linked, defs1_rest, defs2_rest) -> *)
(*     list_in_order id_def_eq id_def_internal defs1 defs1_linked /\ *)
(*     list_in_order id_def_eq id_def_internal defs2 defs2_rest. *)
(* Proof. *)
(*   induction defs1 as [|def1 defs1']. *)
(*   - intros defs2 defs1_linked defs1_rest defs2_rest NORPT LINK. *)
(*     simpl in *. inv LINK. split. *)
(*     constructor. *)
(*     apply list_in_order_refl. *)

(*   - intros defs2 defs1_linked defs1_rest defs2_rest NORPT LINK. *)
(*     simpl in LINK. destruct def1 as (id1, def1). *)
(*     destruct (link_defs1 is_fundef_internal defs1' defs2) eqn:LINK1; try congruence. *)
(*     destruct p as (p, defs2_rest'). *)
(*     destruct p as (defs1_linked', defs1_rest'). *)
(*     destruct (partition (fun '(id', _) => ident_eq id' id1) defs2_rest') as (defs2' & defs2_rest'') eqn:PART. *)
(*     destruct defs2' as [| iddef2 defs2'']. *)
(*     + (** No definition with the same id found in defs2 *) *)
(*       inv LINK. *)
(*       generalize (IHdefs1' _ _ _ _ NORPT LINK1). *)
(*       destruct 1 as (LORDER1 & LORDER2). *)
(*       split; auto.       *)
(*       apply list_in_order_cons; eauto. *)

(*     + (** Some definition with the same id found in defs2 *) *)
(*       destruct iddef2 as (id2 & def2).      *)
(*       destruct (is_def_internal_dec is_fundef_internal def2) as [DEFINT2 | DEFINT2]; *)
(*         rewrite DEFINT2 in LINK. *)
(*       destruct (is_def_internal_dec is_fundef_internal def1) as [DEFINT1 | DEFINT1]; *)
(*         rewrite DEFINT1 in LINK. *)
(*       congruence. *)
(*       inv LINK. *)
(*       * (** The left definition is external and the right definition is internal. *)
(*             The linking is delayed *) *)
(*         generalize (IHdefs1' _ _ _ _ NORPT LINK1). *)
(*         destruct 1 as (LORDER1 & LORDER2). split; auto. *)
(*         apply lorder_left_false; auto. *)

(*       * destruct (link_option def1 def2) as [def|] eqn:LINK_SYMB; inv LINK. *)
(*         (** The right definition is external. *)
(*             The linking proceeds normally *) *)
(*         generalize (IHdefs1' _ _ _ _ NORPT LINK1). *)
(*         destruct 1 as (LORDER1 & LORDER2). *)
(*         generalize (link_defs_rest_norepet_pres2 _ is_fundef_internal _ _ NORPT LINK1). *)
(*         intros NORPT1. *)
(*         generalize (lst_norepet_partition_inv _ _ NORPT1 PART). *)
(*         destruct 1. congruence. destruct H. inv H. *)
(*         subst. split. *)
(*         ** destruct (def_internal def1) eqn:DEFINT1. *)
(*            *** generalize (link_internal_external_defs _ def2 DEFINT1 DEFINT2 LINK_SYMB). *)
(*                intros DEQ.  *)
(*                apply lorder_true. simpl. split; auto. *)
(*                apply PER_Symmetric; auto. *)
(*                auto. *)
(*            *** simpl in LINK_SYMB. inv LINK_SYMB. *)
(*                apply lorder_left_false; auto. *)
(*                apply lorder_right_false; auto. *)
(*                simpl.  *)
(*                apply link_external_defs with def1 def2; eauto. *)
(*         ** generalize (partition_pres_list_in_order _ _ PART). *)
(*            intros LORDER3. *)
(*            apply list_in_order_trans with defs2_rest'; auto. *)
(* Qed. *)

End WithFunVar.
(** *)

Axiom defs_size_inbound: forall defs, sections_size (create_sec_table defs) <= Ptrofs.max_unsigned.

(** Data section generation and linking *)

Lemma extern_var_init_data_nil : forall v,
    is_var_internal v = false ->
    get_def_init_data (Some (Gvar v)) = [].
Proof.
  intros v H. simpl in *.
  unfold is_var_internal in H.
  destruct (gvar_init v); try congruence.
  destruct i; simpl in *; try congruence.
  destruct l; simpl in *; try congruence.
Qed.

Lemma extern_init_data_nil : forall def,
    def_internal def = false -> get_def_init_data def = nil.
Proof.
  intros def H.
  destruct def. destruct g. 
  - simpl in *. auto.
  - simpl in H. apply extern_var_init_data_nil. auto.
  - simpl in *. auto.
Qed.


Lemma acc_init_data_app : forall def l1 l2,
    (acc_init_data def l1) ++ l2 = acc_init_data def (l1 ++ l2).
Proof.
  intros def l1 l2. destruct def as (id & def').
  simpl. rewrite app_assoc. auto.
Qed.

Lemma fold_right_acc_init_data_app : forall defs l,
    fold_right acc_init_data [] defs ++ l = fold_right acc_init_data l defs.
Proof.
  induction defs. 
  - intros l. simpl. auto.
  - intros l. simpl. 
    rewrite acc_init_data_app. rewrite IHdefs. auto.
Qed.

Lemma get_def_init_data_eq : forall d1 d2,
      def_eq d1 d2 -> get_def_init_data d1 = get_def_init_data d2.
Proof.
  intros d1 d2 EQ. inv EQ.
  - simpl. auto.
  - simpl in *. rewrite H1. auto.
Qed.

Lemma acc_init_data_eq: forall d1 d2 l,
    id_def_eq d1 d2 -> acc_init_data d1 l = acc_init_data d2 l.
Proof.
  intros d1 d2 l EQ.
  destruct d1, d2. simpl in *. destruct EQ. subst.
  f_equal. apply get_def_init_data_eq. auto.
Qed.

Lemma acc_init_data_in_order_eq : forall defs1 defs2,
    list_in_order id_def_eq id_def_internal defs1 defs2 ->
    fold_right acc_init_data [] defs1 = fold_right acc_init_data [] defs2.
Proof.
  induction 1.
  - simpl. auto.
  - destruct e as (id, def). simpl.     
    erewrite extern_init_data_nil; eauto.
  - destruct e as (id, def). simpl.
    erewrite extern_init_data_nil; eauto.
  - simpl.
    rewrite IHlist_in_order. auto.
    apply acc_init_data_eq; auto.
Qed.          

(** Hint for Asm definitions *)                
Definition PERIdAsmDefEq := (@PERIdDefEq Asm.function unit).
Existing Instance PERIdAsmDefEq.
Definition IdAsmDefEq := (@IdDefEq Asm.function unit).
Existing Instance IdAsmDefEq.

(* Lemma link_acc_init_data_comm : forall defs1 defs2 defs, *)
(*     list_norepet (map fst defs1) -> *)
(*     list_norepet (map fst defs2) -> *)
(*     link_defs is_fundef_internal defs1 defs2 = Some defs -> *)
(*     fold_right acc_init_data [] defs =  *)
(*     fold_right acc_init_data [] defs1 ++ fold_right acc_init_data [] defs2. *)
(* Proof. *)
(*   intros defs1 defs2 defs NORPT1 NORPT2 LINK. *)
(*   unfold link_defs in LINK. *)
(*   destruct (link_defs1 is_fundef_internal defs1 defs2) eqn:LINK1; try inv LINK. *)
(*   destruct p as (r & defs2_rest). destruct r as (defs1_linked & defs1_rest). *)
(*   destruct (link_defs1 is_fundef_internal defs2_rest defs1_rest) eqn:LINK2; try inv H0. *)
(*   destruct p. destruct p as (defs2_linked & p). inv H1. *)
(*   rewrite fold_right_app. rewrite <- fold_right_acc_init_data_app. *)
(*   generalize (link_defs_rest_norepet_pres1 _ is_fundef_internal defs1 defs2 NORPT1 LINK1). *)
(*   intros NORPT3. *)
(*   apply link_defs1_in_order in LINK1; auto. destruct LINK1 as (ORDER1 & ORDER2). *)
(*   apply link_defs1_in_order in LINK2; auto. destruct LINK2 as (ORDER3 & ORDER4). *)
(*   generalize (list_in_order_trans ORDER2 ORDER3). *)
(*   intros ORDER5. *)
(*   rewrite (acc_init_data_in_order_eq ORDER1). *)
(*   rewrite (acc_init_data_in_order_eq ORDER5). auto.   *)
(* Qed. *)


(** Code section generation and linking *)
Lemma extern_fun_nil : forall def,
    def_internal def = false -> get_def_instrs def = nil.
Proof.
  intros def H.
  destruct def. destruct g; simpl in *.
  - unfold is_fundef_internal in H.
    destruct f; try congruence.
  - auto.
  - simpl in *. auto.
Qed.

Lemma acc_instrs_app : forall def l1 l2,
    (acc_instrs def l1) ++ l2 = acc_instrs def (l1 ++ l2).
Proof.
  intros def l1 l2. destruct def as (id & def').
  simpl. rewrite app_assoc. auto.
Qed.

Lemma fold_right_acc_instrs_app : forall defs l,
    fold_right acc_instrs [] defs ++ l = fold_right acc_instrs l defs.
Proof.
  induction defs. 
  - intros l. simpl. auto.
  - intros l. simpl. 
    rewrite acc_instrs_app. rewrite IHdefs. auto.
Qed.

Lemma get_def_instrs_eq : forall d1 d2,
      def_eq d1 d2 -> get_def_instrs d1 = get_def_instrs d2.
Proof.
  intros d1 d2 EQ. inv EQ.
  - auto.
  - simpl in *. auto.
Qed.

Lemma acc_instrs_eq: forall d1 d2 l,
    id_def_eq d1 d2 -> acc_instrs d1 l = acc_instrs d2 l.
Proof.
  intros d1 d2 l EQ.
  destruct d1, d2. simpl in *. destruct EQ. subst.
  f_equal. apply get_def_instrs_eq. auto.
Qed.

Lemma acc_instrs_in_order_eq : forall defs1 defs2,
    list_in_order id_def_eq id_def_internal defs1 defs2 ->
    fold_right acc_instrs [] defs1 = fold_right acc_instrs [] defs2.
Proof.
  induction 1.
  - simpl. auto.
  - destruct e as (id, def). simpl.     
    erewrite extern_fun_nil; eauto.
  - destruct e as (id, def). simpl.
    erewrite extern_fun_nil; eauto.
  - simpl.
    rewrite IHlist_in_order.
    apply acc_instrs_eq; auto.
Qed.


(* Lemma link_acc_instrs_comm : forall defs1 defs2 defs, *)
(*     list_norepet (map fst defs1) -> *)
(*     list_norepet (map fst defs2) -> *)
(*     link_defs is_fundef_internal defs1 defs2 = Some defs -> *)
(*     fold_right acc_instrs [] defs =  *)
(*     (fold_right acc_instrs [] defs1) ++ (fold_right acc_instrs [] defs2). *)
(* Proof. *)
(*   intros defs1 defs2 defs NORPT1 NORPT2 LINK. *)
(*   unfold link_defs in LINK. *)
(*   destruct (link_defs1 is_fundef_internal defs1 defs2) eqn:LINK1; try inv LINK. *)
(*   destruct p as (r & defs2_rest). destruct r as (defs1_linked & defs1_rest). *)
(*   destruct (link_defs1 is_fundef_internal defs2_rest defs1_rest) eqn:LINK2; try inv H0. *)
(*   destruct p. destruct p as (defs2_linked & p). inv H1. *)
(*   rewrite fold_right_app. rewrite <- fold_right_acc_instrs_app. *)
(*   generalize (link_defs_rest_norepet_pres1 _ is_fundef_internal defs1 defs2 NORPT1 LINK1). *)
(*   intros NORPT3. *)
(*   apply link_defs1_in_order in LINK1; auto. destruct LINK1 as (ORDER1 & ORDER2). *)
(*   apply link_defs1_in_order in LINK2; auto. destruct LINK2 as (ORDER3 & ORDER4). *)
(*   generalize (list_in_order_trans ORDER2 ORDER3). *)
(*   intros ORDER5. *)
(*   rewrite (acc_instrs_in_order_eq ORDER1). *)
(*   rewrite (acc_instrs_in_order_eq ORDER5). auto.   *)
(* Qed. *)

(** Symbol table size *)
Lemma init_data_list_size_app : forall l1 l2,
    init_data_list_size (l1 ++ l2) = (init_data_list_size l1) + (init_data_list_size l2).
Proof.
  induction l1 as [| e l2'].
  - intros l2. simpl. auto.
  - intros l2. simpl in *.
    rewrite IHl2'; omega.
Qed.

Lemma code_size_app: forall l1 l2,
    code_size (l1 ++ l2) = code_size l1 + code_size l2.
Proof.
  induction l1 as [| e l2'].
  - intros l2. simpl. auto.
  - intros l2. simpl in *.
    rewrite IHl2'; omega.
Qed.

Lemma update_code_data_size_inv : forall def dsz csz dincr cincr,
    dincr = init_data_list_size (get_def_init_data def) ->
    cincr = code_size (get_def_instrs def) ->
    update_code_data_size dsz csz def = (dincr + dsz, cincr + csz).
Proof.
  intros def dsz csz dincr cincr DINCR CINCR.
  unfold update_code_data_size. destruct def. destruct g. destruct f.
  - simpl in *. subst. f_equal; omega.
  - simpl in *. subst. f_equal; omega.
  - simpl in DINCR, CINCR. subst.
    destruct (gvar_init v).
    + simpl. auto.
    + destruct i; try (f_equal; omega).
      destruct l; f_equal; omega.
  - simpl in *. subst. f_equal; omega.
Qed.

Lemma acc_symb_size: forall d_id c_id defs s1 s2 dsz1 csz1 dsz2 csz2 data code,
    fold_left (acc_symb d_id c_id) defs (s1, dsz1, csz1) = (s2, dsz2, csz2) ->
    init_data_list_size data = dsz1 ->
    code_size code = csz1 ->
    init_data_list_size (fold_right acc_init_data data defs) = dsz2 /\ 
    code_size (fold_right acc_instrs code defs) = csz2.
Proof.
  induction defs as [| def defs].
  - intros s1 s2 dsz1 csz1 dsz2 csz2 data code SYMB INIT CODE.
    simpl in *. inv SYMB. auto.
  - intros s1 s2 dsz1 csz1 dsz2 csz2 data code SYMB INIT CODE.
    destruct def as (id, def).
    simpl in *. destr_in SYMB.
    rewrite init_data_list_size_app.
    rewrite code_size_app.
    erewrite update_code_data_size_inv in Heqp; eauto.
    inv Heqp.
    rewrite <- init_data_list_size_app in SYMB.
    rewrite <- code_size_app in SYMB.
    generalize (IHdefs _ _ _ _ _ _ _ _ SYMB 
                       (@eq_refl _ (init_data_list_size (get_def_init_data def ++ data)))
                       (@eq_refl _ (code_size (get_def_instrs def ++ code)))).
    destruct 1. subst. split.
    + rewrite <- (fold_right_acc_init_data_app defs data).
      rewrite <- (fold_right_acc_init_data_app defs (get_def_init_data def ++ data)).
      repeat rewrite init_data_list_size_app.
      omega.
    + rewrite <- (fold_right_acc_instrs_app defs code).
      rewrite <- (fold_right_acc_instrs_app defs (get_def_instrs def ++ code)).
      repeat rewrite code_size_app.
      omega.
Qed.


Lemma gen_symb_table_size: forall defs d_id c_id stbl dsz csz,
    gen_symb_table d_id c_id defs = (stbl, dsz, csz) ->
    sec_size (create_data_section defs) = dsz /\
    sec_size (create_code_section defs) = csz.
Proof.
  intros defs d_id c_id stbl dsz csz SGEN.
  simpl. unfold gen_symb_table in SGEN.
  destr_in SGEN. destruct p. inv SGEN. 
  eapply acc_symb_size; eauto.
Qed.


(** ** Main linking theorem *)
(* Lemma link_transf_symbtablegen : forall (p1 p2 : Asm.program) (tp1 tp2 : program) (p : Asm.program), *)
(*     link p1 p2 = Some p -> match_prog p1 tp1 -> match_prog p2 tp2 ->  *)
(*     exists tp : program, link tp1 tp2 = Some tp /\ match_prog p tp. *)
(* Proof. *)
(*   intros p1 p2 tp1 tp2 p LINK MATCH1 MATCH2. *)
(*   unfold link. unfold Linker_reloc_prog. unfold link_reloc_prog. *)
(*   rewrite <- (match_prog_pres_prog_defs MATCH1). *)
(*   rewrite <- (match_prog_pres_prog_defs MATCH2). *)
(*   rewrite <- (match_prog_pres_prog_main MATCH1). *)
(*   rewrite <- (match_prog_pres_prog_main MATCH2). *)
(*   rewrite <- (match_prog_pres_prog_public MATCH1). *)
(*   rewrite <- (match_prog_pres_prog_public MATCH2). *)
(*   setoid_rewrite LINK. *)
(*   apply link_prog_inv in LINK. *)
(*   destruct LINK as (MAINEQ & NRPT1 & NRPT2 & defs & PEQ & LINKDEFS). subst. simpl. *)
(*   unfold match_prog in *. *)

(*   unfold transf_program in MATCH1. *)
(*   destruct check_wellformedness; try monadInv MATCH1. *)
(*   destruct (gen_symb_table sec_data_id sec_code_id (AST.prog_defs p1)) as (p & csz1) eqn:GSEQ1 . *)
(*   destruct p as (stbl1 & dsz1). *)
(*   destruct zle; try monadInv MATCH1; simpl. *)
  
(*   unfold transf_program in MATCH2. *)
(*   destruct check_wellformedness; try monadInv MATCH2. *)
(*   destruct (gen_symb_table sec_data_id sec_code_id (AST.prog_defs p2)) as (p & csz2) eqn:GSEQ2 . *)
(*   destruct p as (stbl2 & dsz2). *)
(*   destruct zle; try monadInv MATCH2; simpl. *)
  
(*   generalize (link_gen_symb_comm _ _ NRPT1 NRPT2 LINKDEFS GSEQ1 GSEQ2  *)
(*                                  (@eq_refl _ (reloc_offset_fun dsz1 csz1))); eauto. *)
(*   destruct 1 as (stbl & stbl2' & RELOC & LINKS & GENS). *)
(*   generalize (gen_symb_table_size _ _ _ GSEQ1). *)
(*   destruct 1 as (DSZ & CSZ). *)
(*   setoid_rewrite DSZ. *)
(*   setoid_rewrite CSZ. *)
(*   rewrite RELOC. *)
(*   unfold reloc_iter. cbn. *)
(*   rewrite LINKS. *)

(*   eexists. split. reflexivity. *)
(*   unfold transf_program. *)

(*   exploit link_pres_wf_prog; eauto. *)
(*   intros WF. *)
(*   destruct check_wellformedness; try congruence. *)
(*   simpl. rewrite GENS. *)
  
(*   destruct zle. *)
(*   repeat f_equal. *)
(*   unfold create_sec_table. repeat f_equal. *)
(*   unfold create_data_section. f_equal. *)
(*   apply link_acc_init_data_comm; auto. *)
(*   unfold create_code_section. f_equal. *)
(*   apply link_acc_instrs_comm; auto. *)
(*   generalize (defs_size_inbound defs). *)
(*   intros; omega. *)
(* Qed. *)

Existing Instance Linker_prog_ordered.

Lemma link_transf_symbtablegen : forall (p1 p2 : Asm.program) (tp1 tp2 : program) (p : Asm.program),
    link p1 p2 = Some p -> match_prog p1 tp1 -> match_prog p2 tp2 ->
    exists tp : program, link tp1 tp2 = Some tp /\ match_prog p tp.
Proof.
  cbn in *.
  Admitted.

Instance TransfLinkSymbtablegen : TransfLink match_prog :=
  link_transf_symbtablegen.