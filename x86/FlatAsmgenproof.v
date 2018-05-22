(* ******************* *)
(* Author: Yuting Wang *)
(* Date:   Feb 7, 2018 *)
(* ******************* *)

(** Correctness proof for the FlatAsm generation **)

Require Import Coqlib Integers Values Maps AST.
Require Import Memtype Memory.
Require Import Smallstep.
Require Import Asm RawAsm.
Require Import FlatAsm FlatAsmgen.
Require Import Segment.
Require Import Events.
Require Import StackADT.
Require Import Linking Errors.
Require Import Globalenvs FlatAsmGlobenv.
Require Import AsmFacts.
Require Import Num.

Open Scope Z_scope.

Ltac monadInvX1 H :=
  let monadInvX H :=  
      monadInvX1 H ||
                 match type of H with
                 | (?F _ _ _ _ _ _ _ _ = OK _) =>
                   ((progress simpl in H) || unfold F in H); monadInvX1 H
                 | (?F _ _ _ _ _ _ _ = OK _) =>
                   ((progress simpl in H) || unfold F in H); monadInvX1 H
                 | (?F _ _ _ _ _ _ = OK _) =>
                   ((progress simpl in H) || unfold F in H); monadInvX1 H
                 | (?F _ _ _ _ _ = OK _) =>
                   ((progress simpl in H) || unfold F in H); monadInvX1 H
                 | (?F _ _ _ _ = OK _) =>
                   ((progress simpl in H) || unfold F in H); monadInvX1 H
                 | (?F _ _ _ = OK _) =>
                   ((progress simpl in H) || unfold F in H); monadInvX1 H
                 | (?F _ _ = OK _) =>
                   ((progress simpl in H) || unfold F in H); monadInvX1 H
                 | (?F _ = OK _) =>
                   ((progress simpl in H) || unfold F in H); monadInvX1 H
                 end
  in

  match type of H with
  | (OK _ = OK _) =>
      inversion H; clear H; try subst
  | (Error _ = OK _) =>
      discriminate
  | (bind ?F ?G = OK ?X) =>
      let x := fresh "x" in (
      let EQ1 := fresh "EQ" in (
      let EQ2 := fresh "EQ" in (
      destruct (bind_inversion F G H) as [x [EQ1 EQ2]];
      clear H;
      try (monadInvX EQ1);
      try (monadInvX1 EQ2))))
  | (bind2 ?F ?G = OK ?X) =>
      let x1 := fresh "x" in (
      let x2 := fresh "x" in (
      let EQ1 := fresh "EQ" in (
      let EQ2 := fresh "EQ" in (
      destruct (bind2_inversion F G H) as [x1 [x2 [EQ1 EQ2]]];
      clear H;
      try (monadInvX EQ1);
      try (monadInvX1 EQ2)))))
  | (match ?X with left _ => _ | right _ => assertion_failed end = OK _) =>
      destruct X eqn:?; [try (monadInvX1 H) | discriminate]
  | (match (negb ?X) with true => _ | false => assertion_failed end = OK _) =>
      destruct X as [] eqn:?; [discriminate | try (monadInvX1 H)]
  | (match ?X with true => _ | false => assertion_failed end = OK _) =>
      destruct X as [] eqn:?; [try (monadInvX1 H) | discriminate]
  | (mmap ?F ?L = OK ?M) =>
      generalize (mmap_inversion F L H); intro
  | (match ?X with Some _ => _ | None => _ end = _) =>
      let EQ := fresh "EQ" in (
      destruct X eqn:EQ; try (monadInvX1 H))
  | (match ?X with pair _ _ => _ end = OK _) =>
      let EQ := fresh "EQ" in (
      destruct X eqn:EQ; try (monadInvX1 H))
  end.

Ltac monadInvX H :=
  monadInvX1 H ||
  match type of H with
  | (?F _ _ _ _ _ _ _ _ = OK _) =>
      ((progress simpl in H) || unfold F in H); monadInvX1 H
  | (?F _ _ _ _ _ _ _ = OK _) =>
      ((progress simpl in H) || unfold F in H); monadInvX1 H
  | (?F _ _ _ _ _ _ = OK _) =>
      ((progress simpl in H) || unfold F in H); monadInvX1 H
  | (?F _ _ _ _ _ = OK _) =>
      ((progress simpl in H) || unfold F in H); monadInvX1 H
  | (?F _ _ _ _ = OK _) =>
      ((progress simpl in H) || unfold F in H); monadInvX1 H
  | (?F _ _ _ = OK _) =>
      ((progress simpl in H) || unfold F in H); monadInvX1 H
  | (?F _ _ = OK _) =>
      ((progress simpl in H) || unfold F in H); monadInvX1 H
  | (?F _ = OK _) =>
      ((progress simpl in H) || unfold F in H); monadInvX1 H
  end.  


Lemma alignw_le : forall x, x <= align x alignw.
Proof.
  intros x. apply align_le. unfold alignw. omega.
Qed.


Lemma divides_align : forall y x,
    y > 0 -> (y | x) -> align x y = x.
Proof.
  intros y x GT DV.
  unfold align. red in DV. destruct DV as [z DV].
  subst. replace (z * y + y - 1) with (z * y + (y - 1)) by omega.
  erewrite Int.Zdiv_shift; eauto.
  erewrite Z_div_mult; eauto. rewrite Z_mod_mult.
  rewrite zeq_true. rewrite Z.add_0_r. auto.
Qed.

Lemma align_idempotent : forall v x,
    x > 0 -> align (align v x) x = align v x.
Proof.
  intros v x H. eapply divides_align; eauto.
  apply align_divides. auto.
Qed.

Definition defs_names_distinct {F V:Type} (defs: list (ident * option (AST.globdef F V))) : Prop :=
  list_norepet (map fst defs).

Lemma nodup_defs_distinct_names: forall defs,
    no_duplicated_defs Asm.fundef unit defs = true ->
    defs_names_distinct defs.
Proof.
  induction defs; intros.
  - red. simpl. constructor.
  - destruct a. simpl in *. 
    destruct (existsb (fun id' : positive => ident_eq i id') (map fst defs)) eqn:EQ.
    inv H.
    apply IHdefs in H. red. red in H. simpl. constructor; auto.
    rewrite <- not_true_iff_false in EQ.
    unfold not in *. intros IN. apply EQ.
    rewrite existsb_exists. exists i. split; auto. 
    destruct ident_eq. auto. congruence.
Qed.


(** Lemmas about FlatAsmgen that are useful for proving invariants *)

Lemma update_instr_pres_gmap : forall i cinfo fid,
    ci_map (update_instr_map fid cinfo i) = ci_map cinfo.
Proof.
  intros i. destruct i.
  destruct i; unfold update_instr_map; simpl; intros; subst; auto.
Qed.

Lemma update_instrs_pres_gmap : forall instrs cinfo fid,
    ci_map (update_instrs_map fid cinfo instrs) = ci_map cinfo.
Proof.
  induction instrs; simpl; intros.
  - subst. auto.
  - apply eq_trans with (ci_map (update_instr_map fid cinfo a)).
    eapply IHinstrs; eauto.
    apply update_instr_pres_gmap; auto.
Qed.


Lemma update_instr_pres_lmap : forall id id' cinfo i l,
    id <> id' ->
    ci_lmap (update_instr_map id' cinfo i) id l = ci_lmap cinfo id l.
Proof.
  intros id id' cinfo i l H.
  destruct i. destruct i; auto.
  simpl. unfold update_label_map. rewrite peq_false; auto.
Qed.

Lemma update_instrs_map_pres_lmap_1 : forall instrs cinfo cinfo' id id' l,
    id <> id' ->
    cinfo' = update_instrs_map id' cinfo instrs ->
    ci_lmap cinfo' id l = ci_lmap cinfo id l.
Proof.
  induction instrs; intros.
  - simpl in *. subst. auto.
  - simpl in H0. eapply eq_trans.
    eapply IHinstrs; eauto.
    erewrite update_instr_pres_lmap; auto.
Qed.

Lemma update_funs_map_pre_maps : forall defs cinfo cinfo' id,
    cinfo' = update_funs_map cinfo defs ->
    ~ In id (map fst defs) ->
    (ci_map cinfo' id = ci_map cinfo id /\
     forall l, ci_lmap cinfo' id l = ci_lmap cinfo id l).
Proof.
  induction defs; intros.
  - simpl in H. subst. auto.
  - assert (id <> fst a /\ ~ In id (map fst defs)) as NOTINCONS
      by (apply not_in_cons; auto).
    destruct NOTINCONS. simpl in H. 
    destruct a. destruct o. destruct g. destruct f. 
    + 
      match type of H with
      | (cinfo' = update_funs_map ?cinfo1 defs) =>
        exploit (IHdefs cinfo1 cinfo'); eauto
      end.
      intros (GMAPEQ & LMAPEQ).
      rewrite update_instrs_pres_gmap in GMAPEQ.
      simpl in GMAPEQ. simpl in H1.
      split.
      * rewrite GMAPEQ. unfold update_gid_map.
        rewrite peq_false; auto. 
      * intros l. specialize (LMAPEQ l).
        rewrite LMAPEQ.
        eapply eq_trans. eapply update_instrs_map_pres_lmap_1; eauto.
        simpl. auto.
    + eapply IHdefs; eauto.
    + eapply IHdefs; eauto.
    + eapply IHdefs; eauto.
Qed.    

Lemma update_funs_map_pre_gmap : forall defs cinfo cinfo' id,
    cinfo' = update_funs_map cinfo defs ->
    ~ In id (map fst defs) ->
    ci_map cinfo' id = ci_map cinfo id.
Proof.
  intros defs cinfo cinfo' id H H0.
  exploit update_funs_map_pre_maps; eauto. destruct 1.
  auto.
Qed.

Lemma update_funs_map_pre_lmap : forall defs cinfo cinfo' id l,
    cinfo' = update_funs_map cinfo defs ->
    ~ In id (map fst defs) ->
    ci_lmap cinfo' id l = ci_lmap cinfo id l.
Proof.
  intros defs cinfo cinfo' id l H H0.
  exploit update_funs_map_pre_maps; eauto. destruct 1.
  auto.
Qed.


Lemma update_extfuns_map_pre_gmap : forall (defs : list (ident * option (globdef Asm.fundef unit)))
                                      (dinfo dinfo' : dinfo) (id : ident)
    (UPDATE: dinfo' = update_extfuns_map dinfo defs)
    (NOTIN: ~ In id (map fst defs)),
    di_map dinfo' id = di_map dinfo id.
Proof.
  induction defs; intros.
  - unfold update_extfuns_map in UPDATE. subst. auto.
  - simpl in NOTIN.
    assert (~ fst a = id /\ ~ In id (map fst defs)) as NOTIN' by auto.
    destruct NOTIN' as [NEQ NOTIN'].
    simpl in UPDATE. destruct a. subst.
    destruct o. destruct g. destruct f.
    + eapply IHdefs; eauto.
    + match goal with
      | [ |- di_map (update_extfuns_map ?di ?df) _ = _ ]
          => exploit (IHdefs di (update_extfuns_map di df)); eauto
      end.
      intros DIMAP. rewrite DIMAP. simpl.
      unfold update_gid_map. destruct peq.
      simpl in NEQ. congruence. auto.
    + eapply IHdefs; eauto.
    + eapply IHdefs; eauto.
Qed.


Lemma update_gvars_map_pre_gmap : forall (defs : list (ident * option (globdef Asm.fundef unit)))
                                      (dinfo dinfo' : dinfo) (id : ident)
    (UPDATE: dinfo' = update_gvars_map dinfo defs)
    (NOTIN: ~ In id (map fst defs)),
    di_map dinfo' id = di_map dinfo id.
Proof.
  induction defs; intros.
  - unfold update_gvars_map in UPDATE. subst. auto.
  - simpl in NOTIN.
    assert (~ fst a = id /\ ~ In id (map fst defs)) as NOTIN' by auto.
    destruct NOTIN' as [NEQ NOTIN'].
    simpl in UPDATE. destruct a. subst.
    destruct o. destruct g. destruct f.
    + eapply IHdefs; eauto.
    + eapply IHdefs; eauto.
    + match goal with
      | [ |- di_map (update_gvars_map ?di ?df) _ = _ ]
          => exploit (IHdefs di (update_gvars_map di df)); eauto
      end.
      intros DIMAP. rewrite DIMAP. simpl.
      unfold update_gid_map. destruct peq.
      simpl in NEQ. congruence. auto.
    + eapply IHdefs; eauto.
Qed.


Lemma update_funs_map_no_effect_gmap : 
  forall defs cinfo' cinfo id def
    (DEFSNAMES: defs_names_distinct defs)
    (UPDATE: cinfo' = update_funs_map cinfo defs)
    (IN: In (id, def) defs)
    (NOTIF: forall f, def <> Some (Gfun (Internal f))),
    ci_map cinfo' id = ci_map cinfo id.
Proof.
  induction defs. intros.
  - inv IN.
  - intros. inv IN.
    + simpl. inv DEFSNAMES. destruct def. destruct g. destruct f.
      specialize (NOTIF f). contradiction.
      eapply update_funs_map_pre_gmap; eauto.
      eapply update_funs_map_pre_gmap; eauto.
      eapply update_funs_map_pre_gmap; eauto.
    + inv DEFSNAMES. 
      generalize (in_map fst defs (id, def) H); eauto. simpl. intros H0.
      destruct a. simpl in H2. destruct o. destruct g. destruct f.
      * match goal with
        | [ |- ci_map (update_funs_map ?ci ?instrs) _ = _ ] 
            => exploit (IHdefs (update_funs_map ci instrs) ci); eauto
        end.
        intros CIMAP. rewrite CIMAP.
        erewrite update_instrs_pres_gmap; eauto. simpl.
        unfold update_gid_map. destruct peq. subst. congruence.
        auto.
      * eapply IHdefs; eauto.
      * eapply IHdefs; eauto.
      * eapply IHdefs; eauto.
Qed.

Lemma update_extfuns_map_no_effect_gmap :
  forall defs dinfo' dinfo id def
    (DEFSNAMES: defs_names_distinct defs)
    (UPDATE: dinfo' = update_extfuns_map dinfo defs)
    (IN: In (id, def) defs)
    (NOTEF: forall f, def <> Some (Gfun (External f))),
    di_map dinfo' id = di_map dinfo id.
Proof.
  induction defs. intros.
  - inv IN.
  - intros.
    inv IN.
    + simpl. inv DEFSNAMES. destruct def. destruct g. destruct f.
      eapply update_extfuns_map_pre_gmap; eauto.
      specialize (NOTEF e). contradiction.
      eapply update_extfuns_map_pre_gmap; eauto.
      eapply update_extfuns_map_pre_gmap; eauto.
    + inv DEFSNAMES.
      generalize (in_map fst defs (id, def) H); eauto. simpl. intros H0.
      destruct a. simpl in H2. destruct o. destruct g. destruct f.
      * eapply IHdefs; eauto.
      * match goal with
        | [ |- di_map (update_extfuns_map ?di ?dfs) _ = _ ]
            => exploit (IHdefs (update_extfuns_map di dfs) di); eauto
        end.
        intros DIMAP. rewrite DIMAP.
        simpl. unfold update_gid_map. destruct peq. subst. congruence.
        auto.
      * eapply IHdefs; eauto.
      * eapply IHdefs; eauto.
Qed.

Lemma update_gvars_map_no_effect_gmap : 
  forall defs dinfo' dinfo id def
    (DEFSNAMES: defs_names_distinct defs)
    (UPDATE: dinfo' = update_gvars_map dinfo defs)
    (IN: In (id, def) defs)
    (NOTVAR: forall v, def <> Some (Gvar v)),
    di_map dinfo' id = di_map dinfo id.
Proof.
  induction defs. intros.
  - inv IN.
  - intros.
    inv IN.
    + simpl. inv DEFSNAMES. destruct def. destruct g. destruct f.
      eapply update_gvars_map_pre_gmap; eauto.
      eapply update_gvars_map_pre_gmap; eauto.
      specialize (NOTVAR v). contradiction.
      eapply update_gvars_map_pre_gmap; eauto.
    + inv DEFSNAMES.
      generalize (in_map fst defs (id, def) H); eauto. simpl. intros H0.
      destruct a. simpl in H2. destruct o. destruct g. destruct f.
      * eapply IHdefs; eauto.
      * eapply IHdefs; eauto.
      * match goal with
        | [ |- di_map (update_gvars_map ?di ?dfs) _ = _ ]
            => exploit (IHdefs (update_gvars_map di dfs) di); eauto
        end.
        intros DIMAP. rewrite DIMAP.
        simpl. unfold update_gid_map. destruct peq. subst. congruence.
        auto.
      * eapply IHdefs; eauto.
Qed.


Lemma transl_fun_exists : forall gmap lmap defs gdefs code f id,
    transl_globdefs gmap lmap defs = OK (gdefs, code) ->
    In (id, Some (Gfun (Internal f))) defs ->
    exists f', transl_fun gmap lmap id f = OK f'
          /\ forall i, In i (fn_code f') -> In i code.
Proof.
  induction defs; simpl; intros.
  - contradiction.
  - destruct a. destruct H0.
    + inv H0. monadInv H. destruct x.
      * destruct p. inv EQ2. monadInv EQ.
        eexists; split; eauto.
        intros. rewrite in_app. auto.
      * monadInv EQ.
    + monadInv H. destruct x.
      * destruct p. inv EQ2. 
        exploit IHdefs; eauto.
        intros (f' & TRANSLF & IN). eexists; split; eauto.
        intros. rewrite in_app. auto.
      * inv EQ2. 
        exploit IHdefs; eauto.
Qed.


(** Lemmas for proving agree_sminj_instr

  The key is to prove that 'Genv.find_instr', given the label of an instruction,
  will find the instruction iteself. This relies critically on the following two properties:

  1. The labels attached to the generated code are distinct;
  2. The mapping from segment ids to segment blocks provided by the FlatAsm environment
     are injective when its range is restricted to "valid blocks", i.e.,
     blocks that correspond to valid segments;

  These two properties are establish by lemmas in the following module which in turn lead to
  the key lemma.
 **)
Module AGREE_SMINJ_INSTR.

(* The following sequence of lemmas is used to prove 

   'update_map_gmap_range'

*)

Lemma tprog_id_in_seg_lists : forall gmap lmap p dsize csize efsize tp id,
  transl_prog_with_map gmap lmap p dsize csize efsize = OK tp ->
  id = code_segid \/ id = data_segid \/ id = extfuns_segid ->
  In id (map segid (list_of_segments tp)).
Proof.
  intros gmap lmap p dsize csize efsize tp id H H0.
  monadInv H. unfold list_of_segments in *. simpl in *.
  destruct H0. auto.
  destruct H. auto. destruct H. auto. 
Qed.

Lemma update_funs_map_id_cases : forall defs cinfo cinfo' id b,
    cinfo' = update_funs_map cinfo defs ->
    ci_map cinfo' id = Some b -> (fst b = code_segid \/ (ci_map cinfo id = Some b)).
Proof.
  induction defs; simpl; intros;
    try (subst; simpl in *; auto).
  destruct a. destruct o. destruct g. destruct f.
  exploit IHdefs; eauto. intros H. destruct H. auto. 
  match type of H with
  | (ci_map (update_instrs_map _ ?ci _) _ = Some _) =>
    generalize (update_instrs_pres_gmap (Asm.fn_code f) ci i)
  end.
  intros H1. rewrite H1 in H.
  simpl in *.
  unfold update_gid_map in H. destruct peq. subst. inv H.
  unfold code_label. simpl. auto. auto.
  eapply IHdefs; eauto.
  eapply IHdefs; eauto.
  eapply IHdefs; eauto.
Qed.

Lemma update_gvars_map_id_cases : forall defs dinfo dinfo' id b,
    dinfo' = update_gvars_map dinfo defs ->
    di_map dinfo' id = Some b -> (fst b = data_segid \/ (di_map dinfo id = Some b)).
Proof.
  induction defs; simpl; intros;
    try (subst; simpl in *; auto).
  destruct a. destruct o. destruct g. 
  eapply IHdefs; eauto.
  exploit IHdefs; eauto. intros H. destruct H. auto.
  unfold update_gvar_map in H. simpl in H.
  unfold update_gid_map in H. destruct peq. subst. inv H.
  unfold data_label. simpl. auto. auto.
  eapply IHdefs; eauto.
Qed.

Lemma update_extfuns_map_id_cases : forall defs dinfo dinfo' id b,
    dinfo' = update_extfuns_map dinfo defs ->
    di_map dinfo' id = Some b -> (fst b = extfuns_segid \/ (di_map dinfo id = Some b)).
Proof.
  induction defs; simpl; intros;
    try (subst; simpl in *; auto).
  destruct a. destruct o. destruct g. destruct f.
  eapply IHdefs; eauto.
  exploit IHdefs; eauto. intros H. destruct H. auto. 
  simpl in *.
  unfold update_gid_map in H. destruct peq. subst. inv H.
  unfold extfun_label. simpl. auto. auto.
  eapply IHdefs; eauto.
  eapply IHdefs; eauto.
Qed.

(* The mapping from global identifers to segment labels generated by
   'update_map' always maps to valid segment labels
   (i.e., labels that will be mapped into valid segment blocks) *)
Theorem update_map_gmap_range : forall p gmap lmap dsize csize efsize tp,
  update_map p = OK (gmap, lmap, dsize, csize, efsize) ->
  transl_prog_with_map gmap lmap p dsize csize efsize = OK tp ->
  forall id slbl, gmap id = Some slbl -> In (fst slbl) (map segid (list_of_segments tp)).
Proof.
  intros p gmap lmap dsize csize efsize tp UPDATE TRANS id b GMAP.
  monadInv UPDATE.
  set (gvmap := (update_gvars_map {| di_size := 0; di_map := default_gid_map |} (AST.prog_defs p))) in *.
  set (efmap := (update_extfuns_map {| di_size := 0; di_map := di_map gvmap |} (AST.prog_defs p))) in *.
  set (fmap := (update_funs_map {| ci_size := 0; ci_map := di_map efmap; ci_lmap := default_label_map |} (AST.prog_defs p))) in *.
  exploit update_funs_map_id_cases; eauto. intros. destruct H.
  eapply tprog_id_in_seg_lists; eauto.
  exploit update_extfuns_map_id_cases; eauto. intros. destruct H0.
  eapply tprog_id_in_seg_lists; eauto.
  exploit update_gvars_map_id_cases; eauto. intros. destruct H1.
  eapply tprog_id_in_seg_lists; eauto.
  simpl in H1. cbv in H1. inv H1.
Qed.


(* The following sequence of lemmas is used to prove 

   'transl_funs_gen_valid_code_labels'

*)

Lemma transl_instrs_gen_valid_code_labels : forall instrs gmap lmap i tp sid ofs1 ofs2 ofs' instrs',
  (forall id b, gmap id = Some b -> In (fst b) (map segid (list_of_segments tp))) ->
  gmap i = Some (sid, ofs1) ->
  transl_instrs gmap lmap i sid ofs2 instrs = OK (ofs', instrs') -> 
  code_labels_are_valid init_block (length (list_of_segments tp)) (gen_segblocks tp) instrs'.
Proof.
  induction instrs; intros.
  - monadInv H1. red. intros. contradiction.
  - monadInv H1.
    assert (code_labels_are_valid init_block (length (list_of_segments tp)) (gen_segblocks tp) x1).
      eapply IHinstrs; eauto.
    apply code_labels_are_valid_cons; auto.
    monadInv EQ. simpl.
    exploit gen_segblocks_in_valid; eauto.
Qed.

Lemma transl_fun_gen_valid_code_labels : forall gmap lmap i f f' tp,
  (forall id b, gmap id = Some b -> In (fst b) (map segid (list_of_segments tp))) ->
  transl_fun gmap lmap i f = OK f' -> 
  code_labels_are_valid init_block (length (list_of_segments tp)) (gen_segblocks tp) (fn_code f').
Proof.
  intros gmap lmap i f f' tp IN TRANSLF.
  monadInvX TRANSLF. destruct zle; try inv EQ2. simpl.
  eapply transl_instrs_gen_valid_code_labels; eauto.
Qed.

(* If the mapping from global identifers to segment labels always maps to valid labels,
   then the code generated by 'transl_funs' using the mapping must also have valid labels *)
Lemma transl_globdefs_gen_valid_code_labels : forall defs gmap lmap tdefs code tp,
  (forall id b, gmap id = Some b -> In (fst b) (map segid (list_of_segments tp))) ->
  transl_globdefs gmap lmap defs = OK (tdefs, code) -> 
  code_labels_are_valid init_block (length (list_of_segments tp)) (gen_segblocks tp) code.
Proof.
  induction defs; intros.
  - monadInv H0. red. intros. inv H0.
  - destruct a. monadInv H0. destruct x. destruct p. destruct o. destruct g.
    destruct f. monadInv EQ. inv EQ2.
    apply code_labels_are_valid_app.
    eapply transl_fun_gen_valid_code_labels; eauto.
    eapply IHdefs; eauto.
    monadInvX EQ. inv EQ2. simpl. eapply IHdefs; eauto.
    monadInvX EQ. inv EQ2. simpl. eapply IHdefs; eauto.
    monadInvX EQ. inv EQ2. simpl. eapply IHdefs; eauto.
Qed.


Lemma transl_funs_gen_valid_code_labels : forall defs gmap lmap fundefs code tp,
  (forall id b, gmap id = Some b -> In (fst b) (map segid (list_of_segments tp))) ->
  transl_funs gmap lmap defs = OK (fundefs, code) -> 
  code_labels_are_valid init_block (length (list_of_segments tp)) (gen_segblocks tp) code.
Proof.
  induction defs; intros.
  - monadInv H0. red. intros. inv H0.
  - monadInvX H0. subst. destruct g. destruct f. monadInv H0.
    apply code_labels_are_valid_app.
    eapply transl_fun_gen_valid_code_labels; eauto.
    eapply IHdefs; eauto.
    eapply IHdefs; eauto.
    eapply IHdefs; eauto.
    eapply IHdefs; eauto.
Qed.

(**************************)
   
Section WITHTRANSF.

Variable prog: Asm.program.
Variable tprog: FlatAsm.program.
Hypothesis TRANSF: transf_program prog = OK tprog.

Let ge := Genv.globalenv prog.
Let tge := globalenv tprog.

(* This lemma makes use of 
   
     'update_map_gmap_range' 

   and 
 
     'transl_funs_gen_valid_code_labels' 

    to prove that the generated instructions have
    valid segment labels attached to them *)
   
Lemma target_code_labels_are_valid : 
  code_labels_are_valid 
    init_block (length (list_of_segments tprog)) 
    (Genv.genv_segblocks tge)
    (snd (code_seg tprog)).
Proof.
  unfold transf_program in TRANSF. 
  destruct (check_wellformedness prog) eqn:WF; monadInv TRANSF. 
  destruct x. destruct p. destruct p. destruct p.
  subst tge. 
  eapply code_labels_are_valid_eq_map. intros.
  symmetry. apply genv_gen_segblocks.
  destruct zle; monadInv EQ0.
  eapply transl_globdefs_gen_valid_code_labels; eauto.
  eapply update_map_gmap_range; eauto.
  unfold transl_prog_with_map. rewrite EQ1.
  simpl. auto.
Qed.

(* The key lemma *)
Lemma find_instr_self : forall i, 
    code_labels_are_distinct (snd (code_seg tprog)) ->
    In i (snd (code_seg tprog)) ->
    Genv.find_instr tge 
                    (Vptr (Genv.genv_segblocks tge (segblock_id (snd i))) (segblock_start (snd i))) = Some i.
Proof.
  intros i DLBL IN. subst tge.
  unfold Genv.find_instr. unfold globalenv.
  erewrite <- add_globals_pres_genv_instrs; eauto. simpl.
  erewrite <- add_globals_pres_genv_segblocks; eauto. simpl.
  set (sbmap := (gen_segblocks tprog)).
  unfold gen_instrs_map.
  set (code := (snd (code_seg tprog))) in *.
  eapply acc_instrs_map_self; eauto.
  apply gen_segblocks_injective.
  set (tge := globalenv tprog).
  subst sbmap code.
  apply code_labels_are_valid_eq_map with (Genv.genv_segblocks tge).
  apply genv_gen_segblocks.
  apply target_code_labels_are_valid.
Qed.


(*************
   The following sequence of lemmas shows that if an instruction is 
   in the source program, then it is translated into an instruction
   in the target program at certain location 
 **********)

Lemma transl_instr_segblock : forall gmap lmap ofs' id i i' sid,
      transl_instr gmap lmap (Ptrofs.unsigned ofs') id sid i = OK i' ->
      segblock_to_label (snd i') = (sid, ofs').
Proof.
  intros. monadInv H. unfold segblock_to_label. simpl.
  rewrite Ptrofs.repr_unsigned. auto.
Qed.

Lemma find_instr_ofs_non_negative : forall code ofs i,
    find_instr ofs code = Some i -> ofs >= 0.
Proof.
  induction code; simpl; intros.
  - inv H.
  - destruct zeq. omega.
    apply IHcode in H. generalize (instr_size_positive a). omega.
Qed.

Lemma transl_instrs_ofs_bound: forall code code' gmap lmap id sid ofs fofs,
  transl_instrs gmap lmap id sid ofs code = OK (fofs, code') -> ofs <= fofs.
Proof.
  induction code; simpl; intros.
  - inv H. omega.
  - monadInv H. apply IHcode in EQ1. 
    generalize (instr_size_positive a). unfold instr_size. omega.
Qed.

Lemma find_instr_transl_instrs : forall code gmap lmap id sid i ofs ofs' fofs code',
    find_instr (Ptrofs.unsigned ofs) code = Some i ->
    transl_instrs gmap lmap id sid (Ptrofs.unsigned ofs') code = OK (fofs, code') ->
    fofs <= Ptrofs.max_unsigned ->
    exists i' ofs1, transl_instr gmap lmap ofs1 id sid i = OK i' 
               /\ segblock_to_label (snd i') = (sid, Ptrofs.add ofs ofs')
               /\ In i' code'.
Proof.
  induction code; simpl; intros.
  - inv H.
  - monadInv H0. destruct zeq.
    + inv H. eexists; eexists; split; eauto.
      rewrite <- (Ptrofs.repr_unsigned ofs). rewrite e. rewrite Ptrofs.add_zero_l. split.
      eapply transl_instr_segblock; eauto. apply in_eq.
    + exploit (IHcode gmap lmap id sid i 
                      (Ptrofs.repr (Ptrofs.unsigned ofs - instr_size a))
                      (Ptrofs.repr (Ptrofs.unsigned ofs' + si_size (snd a)))); eauto.
      rewrite Ptrofs.unsigned_repr. auto. 
      generalize (find_instr_ofs_non_negative code (Ptrofs.unsigned ofs - instr_size a) i H).
      generalize (instr_size_positive a).
      generalize (Ptrofs.unsigned_range_2 ofs). intros. omega.
      rewrite Ptrofs.unsigned_repr. eauto. 
      generalize (transl_instrs_ofs_bound code x1 gmap lmap id sid
                                          (Ptrofs.unsigned ofs' + si_size (snd a)) fofs EQ1).
      generalize (Ptrofs.unsigned_range_2 ofs'). 
      generalize (instr_size_positive a). unfold instr_size. omega.
      intros (i' & ofs1 & TRANSI & SBEQ & IN).
      eexists; eexists; split. eauto. split.
      rewrite SBEQ. f_equal.
      unfold instr_size.
      rewrite Ptrofs.add_unsigned. repeat rewrite Ptrofs.unsigned_repr.
      replace (Ptrofs.unsigned ofs - si_size (snd a) + (Ptrofs.unsigned ofs' + si_size (snd a))) with
              (Ptrofs.unsigned ofs + Ptrofs.unsigned ofs') by omega.
      rewrite <- Ptrofs.add_unsigned. auto.
      generalize (transl_instrs_ofs_bound code x1 gmap lmap id sid
                                          (Ptrofs.unsigned ofs' + si_size (snd a)) fofs EQ1).
      generalize (Ptrofs.unsigned_range_2 ofs'). 
      generalize (instr_size_positive a). unfold instr_size. omega.
      generalize (find_instr_ofs_non_negative code (Ptrofs.unsigned ofs - instr_size a) i H).
      generalize (instr_size_positive a).
      generalize (Ptrofs.unsigned_range_2 ofs). unfold instr_size. intros. omega.
      apply in_cons. auto.
Qed.

Lemma find_instr_transl_fun : forall id f f' ofs i gmap lmap s,
    find_instr (Ptrofs.unsigned ofs) (Asm.fn_code f) = Some i ->
    transl_fun gmap lmap id f = OK f' ->
    gmap id = Some s ->
    exists i' ofs1, transl_instr gmap lmap ofs1 id (fst s) i = OK i' 
               /\ segblock_to_label (snd i') = (fst s, Ptrofs.add ofs (snd s))
               /\ In i' (fn_code f').
Proof.
  intros id f f' ofs i gmap lmap s FINSTR TRANSFUN GMAP.
  unfold transl_fun in TRANSFUN. rewrite GMAP in TRANSFUN.
  monadInvX TRANSFUN. destruct zle; inversion EQ1; clear EQ1.
  exploit find_instr_transl_instrs; eauto.
Qed.

End WITHTRANSF.

End AGREE_SMINJ_INSTR.


(** Lemmas for proving agree_sminj_glob **)
Module AGREE_SMINJ_GLOB.

Lemma update_funs_map_id : forall defs cinfo id slbl,
    ci_map (update_funs_map cinfo defs) id = Some slbl ->
    (ci_map cinfo id = Some slbl \/ In id (map fst defs)).
Proof.
  induction defs; simpl; intros.
  - auto.
  - destruct a. destruct o. destruct g. destruct f.
    + exploit IHdefs; eauto. intros H0. destruct H0.
      match type of H0 with
      | (ci_map (update_instrs_map _ ?ci _) _ = Some _) =>
        generalize (update_instrs_pres_gmap (Asm.fn_code f) ci i)
      end.
      intros H1. rewrite H1 in H0. simpl in H0.
      unfold update_gid_map in H0. destruct peq. subst.
      inv H0. auto. auto. auto.
    + exploit IHdefs; eauto. intros H0. destruct H0; auto.
    + exploit IHdefs; eauto. intros H0. destruct H0; auto.
    + exploit IHdefs; eauto. intros H0. destruct H0; auto.
Qed.


Lemma update_exfuns_map_id : forall defs dinfo id slbl,
    di_map (update_extfuns_map dinfo defs) id = Some slbl ->
    (di_map dinfo id = Some slbl \/ In id (map fst defs)).
Proof.
  induction defs; simpl; intros.
  - auto.
  - destruct a. destruct o. destruct g. destruct f.
    + exploit IHdefs; eauto. intros H0. destruct H0; auto.
    + exploit IHdefs; eauto. intros H0. destruct H0; auto.
      simpl in H0.
      unfold update_gid_map in H0. destruct peq. subst.
      inv H0. auto. auto. 
    + exploit IHdefs; eauto. intros H0. destruct H0; auto.
    + exploit IHdefs; eauto. intros H0. destruct H0; auto.
Qed.
  

Lemma update_gvars_map_id : forall defs dinfo id slbl,
    di_map (update_gvars_map dinfo defs) id = Some slbl ->
    (di_map dinfo id = Some slbl \/ In id (map fst defs)).
Proof.
  induction defs; simpl; intros.
  - auto.
  - destruct a. destruct o. destruct g. destruct f.
    + exploit IHdefs; eauto. intros H0. destruct H0; auto.
    + exploit IHdefs; eauto. intros H0. destruct H0; auto.
    + exploit IHdefs; eauto. intros H0. destruct H0; auto.
      simpl in H0.
      unfold update_gid_map in H0. destruct peq. subst.
      inv H0. auto. auto. 
    + exploit IHdefs; eauto. intros H0. destruct H0; auto.
Qed.

Section WITHTRANSF.

Variable prog: Asm.program.
Variable tprog: FlatAsm.program.
Hypothesis TRANSF: transf_program prog = OK tprog.

Let ge := Genv.globalenv prog.
Let tge := globalenv tprog.

Lemma update_map_gmap_domain : forall gmap lmap dsize csize efsize id slbl, 
    update_map prog = OK (gmap, lmap, dsize, csize, efsize) ->
    gmap id = Some slbl ->
    In id (prog_defs_names prog).
Proof.
  intros gmap lmap dsize csize efsize id slbl H H0.
  monadInv H. 
  exploit update_funs_map_id; eauto. intros H. destruct H; auto.
  exploit update_exfuns_map_id; eauto. intros H1. destruct H1; auto.
  exploit update_gvars_map_id; eauto. intros H2. destruct H2; auto.
  simpl in H2. inv H2.
Qed.

End WITHTRANSF.

End AGREE_SMINJ_GLOB.


(** Lemmas for proving agree_sminj_lbl **)
Module AGREE_SMINJ_LBL.


Fixpoint asm_labels_distinct (c: list Asm.instruction) : Prop :=
  match c with
  | nil => True
  | i::c' => 
    let p := match i with
             | Asm.Plabel l => ~ In i c'
             | _ => True
             end 
    in p /\ asm_labels_distinct c'
  end.

Lemma nodup_labels : forall c,
    no_duplicated_labels c = true -> 
    asm_labels_distinct (map fst c).
Proof.
  induction c; intros.
  - simpl. auto.
  - destruct a. destruct i; simpl; split; auto.
    + 
      destruct (List.existsb 
                  (fun i => match i with
                         | Asm.Plabel l' => ident_eq l l'
                         | _ => false
                         end)
                  (map fst c)) eqn:EQ.
      simpl in H. rewrite EQ in H. congruence.
      rewrite <- not_true_iff_false in EQ. unfold not in *.
      intros. apply EQ. rewrite existsb_exists.
      exists (Asm.Plabel l). split. auto.
      destruct ident_eq. auto. congruence.
    + apply IHc. simpl in H.
      destruct (List.existsb 
                  (fun i => match i with
                         | Asm.Plabel l' => ident_eq l l'
                         | _ => false
                         end)
                  (map fst c)) eqn:EQ.
      congruence.
      auto.
Qed.

Lemma defs_nodup_labels : forall defs f id,
    defs_no_duplicated_labels defs = true ->
    In (id, Some (Gfun (Internal f))) defs ->
    asm_labels_distinct (map fst (Asm.fn_code f)).
Proof.
  induction defs; intros.
  - inv H0.
  - simpl in *. destruct a. destruct o. destruct g. destruct f0.
    + apply andb_true_iff in H. destruct H as [NODUPLBL NODUPDEF].
      destruct H0. inv H.
      * apply nodup_labels. auto.
      * eapply IHdefs; eauto.
    + destruct H0. inv H0.
      eapply IHdefs; eauto.
    + destruct H0. inv H0.
      eapply IHdefs; eauto.
    + destruct H0. inv H0.
      eapply IHdefs; eauto.
Qed.

Ltac solve_label_pos_inv := 
  match goal with
  | [ |- _ <> Asm.Plabel _ /\ label_pos _ _ _ = Some _] =>
    split; solve_label_pos_inv
  | [ |- _ <> Asm.Plabel _ ] =>
    unfold not; inversion 1
  | [ |- label_pos _ _ _ = Some _ ] => auto
  | _ => idtac
  end.

Lemma label_pos_inv : forall l ofs a instrs z,
    label_pos l ofs (a :: instrs) = Some z ->
    (fst a = Asm.Plabel l /\ z = ofs + instr_size a) 
    \/ (fst a <> Asm.Plabel l /\ label_pos l (ofs + instr_size a) instrs = Some z).
Proof.
  intros l ofs a instrs z H.
  simpl in H. destruct a. unfold is_label in H; simpl in H.
  destruct i; try now (right; solve_label_pos_inv).
  destruct peq.
  - subst. left. inv H. auto.
  - right. simpl. split. unfold not. inversion 1. congruence.
    auto.
Qed.


Lemma update_instrs_map_pres_lmap_2 : forall instrs l id cinfo cinfo',
    ~ In (Asm.Plabel l) (map fst instrs) ->
    cinfo' = update_instrs_map id cinfo instrs ->
    ci_lmap cinfo' id l = ci_lmap cinfo id l.
Proof.
  induction instrs; intros.
  - simpl in H0. subst. auto.
  - assert (Asm.Plabel l <> fst a /\ ~ In (Asm.Plabel l) (map fst instrs)) as H1
      by (apply not_in_cons; auto). destruct H1.
    simpl in H0. 
    apply eq_trans with (ci_lmap (update_instr_map id cinfo a) id l).
    eapply IHinstrs; eauto. destruct a.
    destruct i; auto. simpl in *.
    unfold update_label_map. rewrite peq_true. 
    destruct peq. subst. congruence. auto.
Qed.    

Lemma update_gvars_map_size_mono : forall defs dinfo,
    di_size dinfo <= di_size (update_gvars_map dinfo defs).
Proof. 
  induction defs; intros.
  - simpl. omega.
  - simpl. destruct a. destruct o. destruct g.
    apply IHdefs.
    eapply Zle_trans with (di_size (update_gvar_map dinfo i v)).

    unfold update_gvar_map. simpl.
    generalize (init_data_list_size_pos (gvar_init v)). 
    assert (di_size dinfo <= align (di_size dinfo) alignw) by apply alignw_le.
    omega.
    
    apply IHdefs.
    apply IHdefs.
Qed.

Lemma update_extfuns_map_size_mono : forall defs dinfo,
    di_size dinfo <= di_size (update_extfuns_map dinfo defs).
Proof.
  induction defs; intros.
  - simpl. omega.
  - simpl. destruct a. destruct o. destruct g. destruct f.
    apply IHdefs.
    
    match goal with
    | [ |- di_size dinfo <= di_size (update_extfuns_map ?dif _) ] =>
      apply Zle_trans with (di_size dif)
    end.
    simpl. generalize (alignw_le (di_size dinfo)). unfold alignw. omega.
    apply IHdefs.
    apply IHdefs.
    apply IHdefs.
Qed.    

Lemma update_instr_map_size_mono : forall id cinfo i,
    ci_size cinfo <= ci_size (update_instr_map id cinfo i).
Proof.
  intros id cinfo i. destruct i. 
  generalize (si_size_non_zero s). intros H.
  destruct i; simpl; omega.
Qed.

Lemma update_instrs_map_size_mono : forall defs cinfo id,
  ci_size cinfo <= ci_size (update_instrs_map id cinfo defs).
Proof.
  induction defs; intros.
  - simpl. omega.
  - simpl. 
    apply Z.le_trans with (ci_size (update_instr_map id cinfo a)).
    apply update_instr_map_size_mono.
    apply IHdefs.
Qed.

Lemma update_funs_map_pres_size_mono : forall defs cinfo,
    ci_size cinfo <= ci_size (update_funs_map cinfo defs).
Proof.
  induction defs; intros.
  - simpl. omega.
  - simpl. destruct a. destruct o. destruct g. destruct f.
    + match goal with
      | [ |- ci_size _ <= ci_size (update_funs_map ?cif _) ] => 
        apply Z.le_trans with (ci_size cif)
      end. 
      match goal with
      | [ |- ci_size _ <= ci_size (update_instrs_map _ ?cif _) ] => 
        apply Z.le_trans with (ci_size cif)
      end.
      simpl. apply alignw_le. 
      apply update_instrs_map_size_mono.
      apply IHdefs.
    + apply IHdefs.
    + apply IHdefs.
    + apply IHdefs.
Qed.

Lemma update_instrs_map_pres_max_size : forall instrs id size cinfo,
    ci_size (update_instrs_map id cinfo instrs) <= size ->
    ci_size cinfo <= size.
Proof.
  intros instrs id size cinfo H.
  generalize (update_instrs_map_size_mono instrs cinfo id).
  omega.
Qed.

Lemma update_funs_map_pres_max_size : forall defs size cinfo,
    ci_size (update_funs_map cinfo defs) <= size ->
    ci_size cinfo <= size.
Proof.
  intros defs size cinfo H.
  generalize (update_funs_map_pres_size_mono defs cinfo).
  omega.
Qed.

Lemma update_instrs_map_lmap_inversion : forall instrs cinfo l z ofs id cinfo' l'
    (MAXSIZE: ci_size cinfo' <= Ptrofs.max_unsigned)
    (MINSIZE: ci_size cinfo  >= 0),
    asm_labels_distinct (map fst instrs) ->
    label_pos l ofs instrs = Some z ->
    cinfo' = update_instrs_map id cinfo instrs ->
    ci_lmap cinfo' id l = Some l' ->
    (fst l' = code_segid /\ snd l' = Ptrofs.repr (ci_size cinfo + z - ofs)
     /\ 0 <= (ci_size cinfo + z - ofs) <= Ptrofs.max_unsigned).
Proof.
  induction instrs; intros.
  - inv H0.
  - simpl in H1. 
    apply label_pos_inv in H0. destruct H0.
    + destruct H0. simpl in H; rewrite H0 in H; simpl in H. destruct H.
      erewrite update_instrs_map_pres_lmap_2 in H2; eauto.
      destruct a. simpl in H0. subst i. simpl in H2.
      unfold update_label_map in H2. repeat rewrite peq_true in H2. 
      inversion H2. subst z. unfold code_label. simpl. split; auto.
      split. f_equal. omega. subst cinfo'. 
      generalize (update_instrs_map_size_mono instrs 
                (update_instr_map id cinfo (Asm.Plabel l, s)) id).
      intros MAXSIZE'.
      assert (ci_size (update_instr_map id cinfo (Asm.Plabel l, s)) <= Ptrofs.max_unsigned) as MAXSIZE'' by omega.
      unfold update_instr_map in MAXSIZE''; simpl in MAXSIZE''.
      unfold instr_size. simpl. generalize (si_size_non_zero s). omega.
    + destruct H0. 
      generalize (update_instr_map_size_mono id cinfo a). intros SBOUND.
      exploit (IHinstrs (update_instr_map id cinfo a) l z (ofs + instr_size a) id); eauto.
      omega.
      simpl in H. destruct H; auto.
      unfold update_instr_map; simpl. intros (H4 & H5 & H6). split; auto.
      unfold instr_size in H5, H6. 
      rewrite H5. split. f_equal. omega.
      omega.
Qed.

Lemma label_pos_min_size : forall instrs l ofs ofs', 
    label_pos l ofs instrs = Some ofs' -> ofs <= ofs'.
Proof.
  induction instrs; intros.
  - simpl in *. inv H.
  - simpl in *. 
    destruct a. unfold instr_size in *. simpl in *.
    generalize (si_size_non_zero s). intros H0.
    destruct i; try (simpl in *; apply IHinstrs in H; omega).
    unfold is_label in H. simpl in H. destruct peq.
    + subst l0. inv H. omega.
    + apply IHinstrs in H. omega.
Qed.

Lemma update_funs_map_lpos_inversion: forall defs id l f z cinfo' cinfo l'
    (DDISTINCT : defs_names_distinct defs) 
    (LDISTINCT : asm_labels_distinct (map fst (Asm.fn_code f)))
    (MAXSIZE   : ci_size cinfo' <= Ptrofs.max_unsigned)
    (MINSIZE   : ci_size cinfo >= 0),
    In (id, Some (Gfun (Internal f))) defs ->
    label_pos l 0 (Asm.fn_code f) = Some z ->
    cinfo' = update_funs_map cinfo defs -> 
    ci_lmap cinfo' id l = Some l' ->
    (exists slbl : seglabel, ci_map cinfo' id = Some slbl 
                        /\ fst slbl = fst l' 
                        /\ Ptrofs.add (snd slbl) (Ptrofs.repr z) = snd l').
Proof.
  induction defs; intros.
  - contradiction.
  - inv DDISTINCT. inv H.  
    + simpl in *.
      erewrite update_funs_map_pre_lmap in H2; eauto.
      erewrite update_funs_map_pre_gmap; eauto.
      erewrite update_instrs_pres_gmap; eauto. simpl.
      unfold update_gid_map. rewrite peq_true. 
      eexists. split. eauto. unfold code_label. simpl.
      rewrite Ptrofs.add_unsigned.
      apply update_funs_map_pres_max_size in MAXSIZE.
      assert (ci_size cinfo <= align (ci_size cinfo) alignw) as ALIGN by apply alignw_le.
      assert (0 <= z). eapply (label_pos_min_size (Asm.fn_code f) l 0); eauto.
      match type of H2 with
      | (ci_lmap (update_instrs_map _ ?cif _) _ _ = Some _) =>
        exploit (update_instrs_map_lmap_inversion (Asm.fn_code f) cif); eauto
      end.
      simpl. omega.
      intros (LFST & LSND & MAXSIZE'). split; auto. simpl in LSND.
      simpl in MAXSIZE'. rewrite Z.sub_0_r in MAXSIZE'.
      repeat rewrite Ptrofs.unsigned_repr. 
      rewrite LSND. f_equal. omega.  omega. omega.
    + simpl in H2. destruct a. destruct o. destruct g. destruct f0.
      match type of H2 with
      | (ci_lmap (update_funs_map ?cif ?dfs) _ _ = Some _) =>
        exploit (IHdefs id l f z (update_funs_map cif dfs) cif); eauto
      end.
      match goal with
      | [ |- (ci_size (update_instrs_map _ ?cif _) >= _) ] =>
        apply Zge_trans with (ci_size cif)
      end.
      apply Z.le_ge. apply update_instrs_map_size_mono. 
      simpl. apply Z.le_ge. apply Zle_trans with (ci_size cinfo).
      omega. apply alignw_le.
      eapply IHdefs; eauto.
      eapply IHdefs; eauto.
      eapply IHdefs; eauto.
Qed.

Section WITHTRANSF.

Variable prog: Asm.program.
Variable tprog: FlatAsm.program.
Hypothesis TRANSF: transf_program prog = OK tprog.

Let ge := Genv.globalenv prog.
Let tge := globalenv tprog.


Lemma update_map_lmap_inversion : forall id f gmap lmap dsize csize efsize l z l',
    (dsize + csize + efsize) <= Ptrofs.max_unsigned ->
    defs_names_distinct (AST.prog_defs prog) ->
    asm_labels_distinct (map fst (Asm.fn_code f)) ->
    In (id, Some (Gfun (Internal f))) (AST.prog_defs prog) ->
    update_map prog = OK (gmap, lmap, dsize, csize, efsize) ->
    label_pos l 0 (Asm.fn_code f) = Some z ->
    lmap id l = Some l' ->
    exists slbl, gmap id = Some slbl /\
            fst slbl = fst l' /\
            Ptrofs.add (snd slbl) (Ptrofs.repr z) = snd l'.
Proof.
  intros id f gmap lmap dsize csize efsize l z l' SZBOUND DDISTINCT LDISTINCT IN UPDATE LPOS LMAP.
  monadInv UPDATE.
  set (gvinfo := update_gvars_map {| di_size := 0; di_map := default_gid_map |} (AST.prog_defs prog)) in *.
  set (efinfo := update_extfuns_map {| di_size := 0; di_map := di_map gvinfo |} (AST.prog_defs prog)) in *.
  set (cinfo := update_funs_map {| ci_size := 0; ci_map := di_map efinfo; ci_lmap := default_label_map |} (AST.prog_defs prog)) in *.
  exploit (update_funs_map_lpos_inversion (AST.prog_defs prog) id l f z cinfo 
                                          {| ci_size := 0; ci_map := di_map efinfo; ci_lmap := default_label_map |}); eauto.

  generalize (update_gvars_map_size_mono (AST.prog_defs prog) 
                                         {| di_size := 0; di_map := default_gid_map |}). 
  generalize (update_extfuns_map_size_mono (AST.prog_defs prog) 
                                           {| di_size := 0; di_map := di_map gvinfo |}). 
  simpl. fold gvinfo efinfo. 
  intros EFSIZE GVSIZE.
  assert ((di_size efinfo) <= align (di_size efinfo) alignw) by apply alignw_le.
  assert ((di_size gvinfo) <= align (di_size gvinfo) alignw) by apply alignw_le.
  assert ((ci_size cinfo) <= align (ci_size cinfo) alignw) by apply alignw_le.
  omega.

  simpl. omega.
Qed.

End WITHTRANSF.

End AGREE_SMINJ_LBL.


Section WITHMEMORYMODEL.
  
Context `{memory_model: Mem.MemoryModel }.
Existing Instance inject_perm_all.

Definition match_prog (p: Asm.program) (tp: FlatAsm.program) :=
  transf_program p = OK tp.


Section PRESERVATION.

Variable prog: Asm.program.
Variable tprog: FlatAsm.program.
Hypothesis TRANSF: match_prog prog tprog.

Let ge := Genv.globalenv prog.
Let tge := globalenv tprog.

Definition regset_inject (j:meminj) (rs rs' : regset) : Prop :=
  forall r, Val.inject j (rs r) (rs' r).

(** Agreement between a memory injection from Asm to the flat memory and 
    the mappings for segments, global id and labels *)    
Record match_sminj (gm: GID_MAP_TYPE) (lm: LABEL_MAP_TYPE) (mj: meminj) : Type :=
  mk_match_sminj {

      agree_sminj_instr :  forall b b' f ofs ofs' i,
        Genv.find_funct_ptr ge b = Some (Internal f) -> 
        Asm.find_instr (Ptrofs.unsigned ofs) (Asm.fn_code f) = Some i ->
        mj b = Some (b', ofs') -> 
        exists id i' sid ofs1, 
          Genv.find_instr tge (Vptr b' (Ptrofs.add ofs (Ptrofs.repr ofs'))) = Some i' /\
          Genv.find_symbol ge id = Some b /\
          transl_instr gm lm ofs1 id sid i = OK i';

      agree_sminj_glob : forall id gloc,
          gm id = Some gloc ->
          exists ofs' b b', 
            Genv.find_symbol ge id = Some b /\
            Genv.symbol_address tge gloc Ptrofs.zero = Vptr b' ofs' /\
            mj b = Some (b', Ptrofs.unsigned ofs');

      agree_sminj_lbl : forall id b f l z l',
          Genv.find_symbol ge id = Some b ->
          Genv.find_funct_ptr ge b = Some (Internal f) ->
          label_pos l 0 (Asm.fn_code f) = Some z ->
          lm id l = Some l' ->
          Val.inject mj (Vptr b (Ptrofs.repr z)) (Genv.symbol_address tge l' Ptrofs.zero);
      
    }.

Definition gid_map_for_undef_syms (gm: GID_MAP_TYPE) :=
  forall id, Genv.find_symbol ge id = None -> gm id = None.


Definition valid_instr_offset_is_internal (mj:meminj) :=
  forall b b' f ofs i ofs',
    Genv.find_funct_ptr ge b = Some (Internal f) ->
    find_instr (Ptrofs.unsigned ofs) (Asm.fn_code f) = Some i ->
    mj b = Some (b', ofs') ->
    Genv.genv_internal_codeblock tge b' = true.    

Definition extfun_entry_is_external (mj:meminj) :=
  forall b b' f ofs,
    Genv.find_funct_ptr ge b = Some (External f) ->
    mj b = Some (b', ofs) ->
    Genv.genv_internal_codeblock tge b' = false.


Definition def_frame_inj m := (flat_frameinj (length (Mem.stack m))).

Lemma store_pres_def_frame_inj : forall chunk m1 b ofs v m1',
    Mem.store chunk m1 b ofs v = Some m1' ->
    def_frame_inj m1 = def_frame_inj m1'.
Proof.
  unfold def_frame_inj. intros.
  repeat erewrite Mem.push_new_stage_stack. simpl.
  exploit Mem.store_stack_blocks; eauto. intros. rewrite H0.
  auto.
Qed.

Lemma storev_pres_def_frame_inj : forall chunk m1 v1 v2 m1',
    Mem.storev chunk m1 v1 v2 = Some m1' ->
    def_frame_inj m1= def_frame_inj m1'.
Proof.
  intros until m1'. unfold Mem.storev.
  destruct v1; try congruence.
  intros STORE.
  eapply store_pres_def_frame_inj; eauto.
Qed.


Lemma store_mapped_inject' : 
  forall (f : meminj) (chunk : memory_chunk) 
    (m1 : mem) (b1 : block) (ofs : Z) (v1 : val) 
    (n1 m2 : mem) (b2 : block) (delta : Z) (v2 : val),
    Mem.inject f (def_frame_inj m1) m1 m2 ->
    Mem.store chunk m1 b1 ofs v1 = Some n1 ->
    f b1 = Some (b2, delta) ->
    Val.inject f v1 v2 ->
    exists n2 : mem,
      Mem.store chunk m2 b2 (ofs + delta) v2 = Some n2 /\
      Mem.inject f (def_frame_inj n1) n1 n2.
Proof.
  intros. exploit Mem.store_mapped_inject; eauto. 
  intros (n2 & STORE & MINJ).
  eexists. split. eauto.
  erewrite <- store_pres_def_frame_inj; eauto.
Qed.

Theorem storev_mapped_inject':
  forall f chunk m1 a1 v1 n1 m2 a2 v2,
  Mem.inject f (def_frame_inj m1) m1 m2 ->
  Mem.storev chunk m1 a1 v1 = Some n1 ->
  Val.inject f a1 a2 ->
  Val.inject f v1 v2 ->
  exists n2,
    Mem.storev chunk m2 a2 v2 = Some n2 /\ Mem.inject f (def_frame_inj n1) n1 n2.
Proof.
  intros. exploit Mem.storev_mapped_inject; eauto. 
  intros (n2 & STORE & MINJ).
  eexists. split. eauto.
  erewrite <- storev_pres_def_frame_inj; eauto.
Qed.

Definition match_find_funct (j:meminj) :=
  forall b f ofs b',
  Genv.find_funct_ptr ge b = Some (External f) ->
  j b = Some (b', ofs) ->
  Genv.find_funct tge (Vptr b' (Ptrofs.repr ofs)) = Some (External f).

Definition glob_block_valid (m:mem) := 
  forall b g, Genv.find_def ge b = Some g -> Mem.valid_block m b.

Inductive match_states: state -> state -> Prop :=
| match_states_intro: forall (j:meminj) (rs: regset) (m: mem) (rs': regset) (m':mem)
                        (gm: GID_MAP_TYPE) (lm: LABEL_MAP_TYPE)
                        (MINJ: Mem.inject j (def_frame_inj m) m m')
                        (MATCHSMINJ: match_sminj gm lm j)
                        (* (GINJFLATMEM: globs_inj_into_flatmem j) *)
                        (INSTRINTERNAL: valid_instr_offset_is_internal j)
                        (EXTEXTERNAL: extfun_entry_is_external j)
                        (MATCHFINDFUNCT: match_find_funct j)
                        (RSINJ: regset_inject j rs rs')
                        (GBVALID: glob_block_valid m)
                        (GMUNDEF: gid_map_for_undef_syms gm),
    match_states (State rs m) (State rs' m').


(* Definition seglabel_to_ptr (slbl: seglabel) (stob : segid_type -> block) : (block * Z) := *)
(*   let (sid, ofs) := slbl in *)
(*   (stob sid, Ptrofs.unsigned ofs). *)

Definition init_meminj (gmap: GID_MAP_TYPE) : meminj :=
  let ge := Genv.globalenv prog in
  let tge := globalenv tprog in
  fun b => 
    (* (genv_next ge) is the stack block of the source program *)
    if eq_block b (Globalenvs.Genv.genv_next ge) 
    then Some (Genv.genv_next tge, 0)
    else
      match (Genv.invert_symbol ge b) with
      | None => None
      | Some id => 
        match (gmap id) with
        | None => None
        | Some slbl => Some (Genv.symbol_block_offset tge slbl)
        end
      end.

Theorem init_meminj_match_sminj : forall gmap lmap dsize csize efsize m,
    dsize + csize + efsize <= Ptrofs.max_unsigned ->
    Genv.init_mem prog = Some m ->
    update_map prog = OK (gmap,lmap,dsize,csize,efsize) ->
    transl_prog_with_map gmap lmap prog dsize csize efsize = OK tprog ->
    match_sminj gmap lmap (init_meminj gmap).
Proof.   
  intros gmap lmap dsize csize efsize m MAX INITMEM UPDATE TRANS. 
  generalize TRANSF. intros TRANSF'.
  unfold match_prog in TRANSF'. 
  unfold transf_program in TRANSF'. 
  destruct (check_wellformedness prog) eqn:WF; monadInv TRANSF'.
  rewrite UPDATE in EQ. inv EQ. clear EQ0.
  generalize UPDATE. intros UPDATE'.
  unfold update_map in UPDATE. 
  set (dinfo_gvars := update_gvars_map {| di_size := 0; di_map := default_gid_map |} (AST.prog_defs prog)) in *.
  set (dinfo_extfuns := (update_extfuns_map {| di_size := 0; di_map := di_map dinfo_gvars |} (AST.prog_defs prog))) in *.
  set (cinfo_funs := (update_funs_map {| ci_size := 0; ci_map := di_map dinfo_extfuns; ci_lmap := default_label_map |} (AST.prog_defs prog))) in *.
  inv UPDATE. 
  monadInv TRANS.
  (* rename EQ into TRANSGV. rename EQ1 into TRANSFUN. rename EQ0 into TRANSEF. *)
  (* rename x into gvars. rename x0 into gfuns. rename x2 into efuns. rename x1 into code. *)
  rename x into tgdefs. rename x0 into code.
  constructor.
  - (* agree_sminj_instr *) 
    intros b b' f ofs ofs' i FPTR FINST INITINJ.
    unfold init_meminj in INITINJ. fold ge in INITINJ.
    destruct (eq_block b (Globalenvs.Genv.genv_next ge)); inversion INITINJ. 
    subst ofs' b' b. clear INITINJ.
    + exfalso. subst ge. eapply Genv.genv_next_find_funct_ptr_absurd; eauto. 
    + destruct (Genv.invert_symbol ge b) eqn:INVSYM; inversion H1.
      destruct (ci_map cinfo_funs i0) eqn:CIMAP; inversion H2.
      subst ofs' b'. clear INITINJ H1 H2.
      rewrite Ptrofs.repr_unsigned. rename i0 into id.
      apply Genv.invert_find_symbol in INVSYM.
      exploit (Genv.find_symbol_funct_ptr_inversion prog); eauto.
      intros FINPROG.
      exploit transl_fun_exists; eauto. intros (f' & TRANSLFUN' & INR).
      exploit AGREE_SMINJ_INSTR.find_instr_transl_fun; eauto. 
      intros (i' & ofs1 & TRANSINSTR & SEGLBL & IN).
      exists id, i', (fst s), ofs1. split. 
      unfold segblock_to_label in SEGLBL. inversion SEGLBL.
      apply INR in IN.
      eapply AGREE_SMINJ_INSTR.find_instr_self; eauto. 
      
      admit. subst tprog; simpl. auto.
      split; auto.

  - (* agree_sminj_glob *)
    intros id gloc GMAP.
    assert (In id (prog_defs_names prog)) 
      by (eapply AGREE_SMINJ_GLOB.update_map_gmap_domain; eauto).
    exploit Genv.find_symbol_exists_1; eauto.
    intros (b & FIND).
    esplit. exists b. esplit. split. auto. split.
    unfold Genv.symbol_address. unfold Genv.label_to_ptr. auto.
    unfold init_meminj.       
    destruct eq_block. exfalso. subst b. eapply Genv.find_symbol_genv_next_absurd; eauto.    
    apply Genv.find_invert_symbol in FIND. subst ge. rewrite FIND. rewrite GMAP.
    unfold Genv.symbol_block_offset. unfold Genv.label_to_block_offset.
    repeat rewrite offset_seglabel_zero. auto.

  - (* agree_sminj_lbl *)
    intros id b f l z l' FINDSYM FINDPTR LPOS LPOS'.
    subst ge. 
    exploit Genv.find_symbol_funct_ptr_inversion; eauto. intros INDEFS.
    exploit transl_fun_exists; eauto.
    intros (f' & TRANSLF & INCODE).
    set (ge := Genv.globalenv prog).
    exploit AGREE_SMINJ_LBL.update_map_lmap_inversion; eauto. 

    unfold check_wellformedness in WF.
    repeat rewrite andb_true_iff in WF. destruct WF as (FNONEMPTY & NODUPDEFS & NODUPLBLS).
    apply nodup_defs_distinct_names. auto.

    unfold check_wellformedness in WF.
    repeat rewrite andb_true_iff in WF. destruct WF as (FNONEMPTY & NODUPDEFS & NODUPLBLS).
    eapply AGREE_SMINJ_LBL.defs_nodup_labels; eauto.

    intros (slbl & GMAP & LEQ & OFSEQ).
    unfold Genv.symbol_address. unfold Genv.label_to_ptr. 
    apply Val.inject_ptr with (Ptrofs.unsigned (snd slbl)).   
    unfold init_meminj. destruct eq_block.
    subst b. exfalso. 
    eapply Genv.find_symbol_genv_next_absurd; eauto.
    erewrite Genv.find_invert_symbol; eauto.
    rewrite offset_seglabel_zero. 
    unfold Genv.symbol_block_offset. unfold Genv.label_to_block_offset.
    rewrite GMAP. rewrite LEQ. auto.
    rewrite offset_seglabel_zero. rewrite Ptrofs.repr_unsigned. symmetry.
    rewrite Ptrofs.add_commut. auto.
Admitted.
    

Lemma alloc_pres_def_frame_inj : forall m1 lo hi m1' b,
    Mem.alloc m1 lo hi = (m1', b) ->
    def_frame_inj m1 = def_frame_inj m1'.
Proof.
  unfold def_frame_inj. intros.
  apply Mem.alloc_stack_blocks in H. rewrite H. auto.
Qed.

(** Proving initial memory injection **)

Definition partial_genv defs : Globalenvs.Genv.t Asm.fundef unit := 
  let emptyge := (Globalenvs.Genv.empty_genv Asm.fundef unit prog.(AST.prog_public)) in
  Globalenvs.Genv.add_globals emptyge defs.

Definition globs_meminj defs (gmap: GID_MAP_TYPE) : meminj :=
  fun b => 
      match (Genv.invert_symbol (partial_genv defs) b) with
      | None => None
      | Some id => 
        match (gmap id) with
        | None => None
        | Some slbl => Some (Genv.label_to_block_offset (gen_segblocks tprog) slbl)
        end
      end.

Ltac destr_if := 
  match goal with 
  | [ |- context [if ?b then _ else _] ] => 
    let eq := fresh "EQ" in
    (destruct b eqn:eq)
  end.

Ltac destr_match := 
  match goal with 
  | [ |- context [match ?b with _ => _ end] ] => 
    let eq := fresh "EQ" in
    (destruct b eqn:eq)
  end.

Ltac destr_match_in H := 
  match type of H with 
  | context [match ?b with _ => _ end] => 
    let eq := fresh "EQ" in
    (destruct b eqn:eq)
  end.

Lemma find_symbol_add_global_eq : forall (F V: Type) (ge:Globalenvs.Genv.t F V) i def,
    Globalenvs.Genv.find_symbol (Globalenvs.Genv.add_global ge (i, def)) i = Some (Globalenvs.Genv.genv_next ge).
Proof.
  intros F V ge0 i def. unfold Genv.find_symbol.
  unfold Genv.add_global. simpl. rewrite PTree.gss. auto.
Qed.

Lemma find_symbol_add_global_neq : forall (F V: Type) (ge:Globalenvs.Genv.t F V) i i' def,
    i <> i' -> 
    Globalenvs.Genv.find_symbol (Globalenvs.Genv.add_global ge (i, def)) i' = 
    Globalenvs.Genv.find_symbol ge i'.
Proof.
  intros F V ge0 i i' def H. unfold Genv.find_symbol.
  unfold Genv.add_global. simpl. rewrite PTree.gso; auto.
Qed.

Lemma invert_symbol_add_global_none : forall (F V: Type) (ge:Globalenvs.Genv.t F V) id def b,
    Genv.invert_symbol (Genv.add_global ge (id, def)) b = None ->
    Genv.invert_symbol ge b = None.
Proof.
  unfold Genv.add_global. unfold Genv.invert_symbol. simpl.
  intros F V ge0 id def b H.
  rewrite PTree.fold_spec. rewrite PTree.fold_spec in H.
Admitted.  

(* Lemma invert_symbol_add_global : forall (F V: Type) (ge ge':Globalenvs.Genv.t F V) id def b, *)
(*     ge' = Genv.add_global ge (id, def) -> *)
(*     Genv.invert_symbol ge' b = Some id  *)
(*     \/ Genv.invert_symbol ge' b = Genv.invert_symbol ge b. *)
(* Proof. *)
(*   intros F V ge0 ge' id def b H. *)
(*   destruct (Genv.invert_symbol ge' b) eqn:EQ1. *)
(*   - apply Genv.invert_find_symbol in EQ1. subst ge'. *)
(*     destruct (ident_eq i id). *)
(*     + subst. auto. *)
(*     + erewrite find_symbol_add_global_neq in EQ1; eauto. *)
(*       apply Genv.find_invert_symbol in EQ1. auto. *)
(*   - admit. *)

Lemma globs_meminj_none_pres :
  forall i gmap defs x , gmap i = None -> globs_meminj defs gmap x = globs_meminj (defs ++ (i, None)::nil) gmap x.
Proof.
  intros i gmap ids x GMAP. unfold globs_meminj.
  destruct (Genv.invert_symbol (partial_genv (ids ++ (i, None) :: nil)) x) eqn:EQ.
  - apply Genv.invert_find_symbol in EQ. 
    unfold partial_genv in EQ. rewrite Genv.add_globals_app in EQ. simpl in EQ.
    destruct (ident_eq i i0).
    + subst i0. rewrite find_symbol_add_global_eq in EQ. inv EQ.
      rewrite Genv.invert_symbol_genv_next. rewrite GMAP. auto.
    + erewrite find_symbol_add_global_neq in EQ; eauto.
      apply Genv.find_invert_symbol in EQ. setoid_rewrite EQ. auto.
  - unfold partial_genv in EQ. rewrite Genv.add_globals_app in EQ. simpl in EQ.
    apply invert_symbol_add_global_none in EQ. setoid_rewrite EQ. auto.
Qed.

Lemma update_funs_map_none :
  forall defs cinfo' cinfo id
    (DEFSNAMES: defs_names_distinct defs)
    (UPDATE: cinfo' = update_funs_map cinfo defs)
    (IN: In (id, None) defs),
    ci_map cinfo' id = ci_map cinfo id.
Proof.
  intros. eapply update_funs_map_no_effect_gmap; eauto.
  intros. intro. discriminate.
Qed.
    

Lemma update_extfuns_map_none :
  forall defs dinfo' dinfo id
    (DEFSNAMES: defs_names_distinct defs)
    (UPDATE: dinfo' = update_extfuns_map dinfo defs)
    (IN: In (id, None) defs),
    di_map dinfo' id = di_map dinfo id.
Proof.
  intros. eapply update_extfuns_map_no_effect_gmap; eauto.
  intros. intro. discriminate.
Qed.

Lemma update_gvars_map_none : 
  forall defs dinfo' dinfo id
    (DEFSNAMES: defs_names_distinct defs)
    (UPDATE: dinfo' = update_gvars_map dinfo defs)
    (IN: In (id, None) defs),
    di_map dinfo' id = di_map dinfo id.
Proof.
  intros. eapply update_gvars_map_no_effect_gmap; eauto.
  intros. intro. discriminate.
Qed.
  

Lemma update_map_gmap_none :
  forall (prog : Asm.program) (gmap : GID_MAP_TYPE) (lmap : LABEL_MAP_TYPE) (dsize csize efsize : Z) (id : ident)
    (DEFSNAMES: defs_names_distinct (AST.prog_defs prog))
    (UPDATE: update_map prog = OK (gmap, lmap, dsize, csize, efsize))
    (IN: In (id, None) (AST.prog_defs prog)),
    gmap id = None.
Proof.
  intros. monadInv UPDATE.
  set (gvmap := (update_gvars_map {| di_size := 0; di_map := default_gid_map |} (AST.prog_defs prog0))) in *.
  set (efmap := (update_extfuns_map {| di_size := 0; di_map := di_map gvmap |} (AST.prog_defs prog0))) in *.
  set (fmap := (update_funs_map {| ci_size := 0; ci_map := di_map efmap; ci_lmap := default_label_map |} (AST.prog_defs prog0))) in *.
  exploit (update_funs_map_none (AST.prog_defs prog0) fmap); eauto. unfold fmap. eauto.
  simpl. intros PMAP1. rewrite PMAP1.
  exploit (update_extfuns_map_none (AST.prog_defs prog0) efmap); eauto. unfold efmap. eauto.
  simpl. intros PMAP2. rewrite PMAP2.
  exploit (update_gvars_map_none (AST.prog_defs prog0) gvmap); eauto. unfold gvmap. eauto.
  simpl. intros PMAP3. rewrite PMAP3. auto.
Qed.
  
  

Lemma invert_add_global_genv_next : forall (F V: Type) (ge:Globalenvs.Genv.t F V) id def,
    Genv.invert_symbol (Genv.add_global ge (id, def)) (Globalenvs.Genv.genv_next ge) = Some id.
Proof.
  intros. apply Genv.find_invert_symbol.
  apply find_symbol_add_global_eq.
Qed.

Lemma partial_genv_invert_symbol : forall defs id def,
    Genv.invert_symbol (partial_genv (defs ++ (id, def) :: nil)) (Globalenvs.Genv.genv_next (partial_genv defs)) = Some id.
Proof.
  intros defs id def. unfold partial_genv. 
  rewrite Genv.add_globals_app. simpl.
  apply invert_add_global_genv_next.
Qed.

Lemma partial_genv_find_symbol_eq : forall defs id def,
    Genv.find_symbol (partial_genv (defs ++ (id, def) :: nil)) id = Some (Globalenvs.Genv.genv_next (partial_genv defs)).
Proof.
  intros defs id def. apply Genv.invert_find_symbol.
  apply partial_genv_invert_symbol.
Qed.

Lemma partial_genv_find_symbol_neq : forall defs id id' def,
    id <> id' -> 
    Genv.find_symbol (partial_genv (defs ++ (id, def) :: nil)) id' = Genv.find_symbol (partial_genv defs) id'.
Proof.
  intros defs id id' def H. unfold partial_genv. rewrite Genv.add_globals_app.
  simpl. rewrite find_symbol_add_global_neq; auto.
Qed.


Lemma partial_genv_find_symbol_inversion : forall defs x b,
  Genv.find_symbol (partial_genv defs) x = Some b ->
  In x (map fst defs).
Admitted.


Lemma update_funs_map_app : forall defs1 defs2 cinfo cinfo'
    (UPDATE: cinfo' = update_funs_map cinfo (defs1 ++ defs2)),
    exists cinfo1, cinfo1 = update_funs_map cinfo defs1 /\
              cinfo' = update_funs_map cinfo1 defs2.
Proof.
  induction defs1; intros.
  - simpl in UPDATE. eexists. split. eauto. auto.
  - simpl in UPDATE. destruct a. destruct o. destruct g. destruct f.
    + apply IHdefs1 in UPDATE. 
      destruct UPDATE as [cinfo1 [CINFO1 CINFO']].
      exists cinfo1. split; auto.
    + apply IHdefs1 in UPDATE.       
      destruct UPDATE as [cinfo1 [CINFO1 CINFO']].
      exists cinfo1. split; auto.
    + apply IHdefs1 in UPDATE.       
      destruct UPDATE as [cinfo1 [CINFO1 CINFO']].
      exists cinfo1. split; auto.
    + apply IHdefs1 in UPDATE.       
      destruct UPDATE as [cinfo1 [CINFO1 CINFO']].
      exists cinfo1. split; auto.
Qed.

Definition seglabel_bound (ci: cinfo) (sid: segid_type) : Prop :=
  forall id slbl, (ci_map ci id = Some slbl) -> fst slbl = sid
               -> Ptrofs.unsigned (snd slbl) < ci_size ci.

Definition fun_non_empty (def: AST.globdef Asm.fundef unit) : Prop :=
  match def with
  | Gfun (Internal f) =>
    (0 < length (Asm.fn_code f))%nat
  | _ => True
  end.

Definition defs_funs_non_empty (defs: list (ident * option (AST.globdef Asm.fundef unit))) : Prop :=
  Forall (fun '(id, def) =>
            match def with
            | None => True
            | Some def' => fun_non_empty def'
            end
         ) defs.

Lemma defs_funs_non_empty_cons_inv : forall a l,
  defs_funs_non_empty (a::l) -> defs_funs_non_empty l.
Proof.
  unfold defs_funs_non_empty. intros a l H.
  inv H. auto.
Qed.

Lemma update_funs_map_bound :
  forall defs cinfo cinfo' 
    (DEFSNONEMPTY : defs_funs_non_empty defs)
    (DEFSNAMES: defs_names_distinct defs)
    (SLBOUND : seglabel_bound cinfo code_segid)
    (UPDATE: cinfo' = update_funs_map cinfo defs),
    seglabel_bound cinfo' code_segid.
Proof.
  induction defs; simpl; intros.
  - subst. auto.
  - inv DEFSNAMES. destruct a. destruct o. destruct g. destruct f.
    + match goal with 
      | [ |- context[ update_funs_map ?ci _ ] ] =>
        eapply (IHdefs ci); eauto
      end.
      eapply defs_funs_non_empty_cons_inv; eauto.
      red. intros id slbl CIMAP FST.
      erewrite update_instrs_pres_gmap in CIMAP; eauto. simpl in CIMAP.
      unfold update_gid_map in CIMAP. destruct peq.
      * subst. inv CIMAP. unfold code_label. simpl.
        rewrite Ptrofs.unsigned_repr.
Admitted.
      

Lemma update_map_gmap_some_internal :
  forall defs1 cinfo cinfo' id f defs defs2
    (DEFSNAMES: defs_names_distinct defs)
    (* (SLBOUND : seglabel_bound cinfo code_segid) *)
    (UPDATE: cinfo' = update_funs_map cinfo defs)
    (DEFS: (defs1 ++ (id, Some (Gfun (Internal f))) :: defs2) = defs),
    exists slbl, ci_map cinfo' id = Some slbl 
           /\ (forall id' slbl', In id' (map fst defs1) -> (ci_map cinfo' id' = Some slbl') ->
              fst slbl' = fst slbl -> Ptrofs.unsigned (snd slbl') < Ptrofs.unsigned (snd slbl)).
Proof.
  induction defs1; intros.
  - subst. simpl in *. inv DEFSNAMES.
    erewrite update_funs_map_pre_gmap; eauto.
    erewrite update_instrs_pres_gmap; eauto. simpl.
    unfold update_gid_map. rewrite peq_true. eexists. split. eauto.
    intros. contradiction.
  - destruct a.
    assert (defs_names_distinct (defs1 ++ (id, Some (Gfun (Internal f))) :: defs2)) as DEFSNAMES'.
    { subst. inv DEFSNAMES. auto. }
    rewrite <- DEFS in UPDATE. simpl in UPDATE. destruct o. destruct g. destruct f0.
    (* internal function *)
    match type of UPDATE with
    | _ = update_funs_map ?ci _ =>
      exploit (IHdefs1 ci); eauto
    end.
    (* red. intros id' slbl' CIMAP LBL.     *)
    (* erewrite update_instrs_pres_gmap in CIMAP; eauto.  simpl in CIMAP. *)
    (* unfold update_gid_map in CIMAP. *)
    (* destruct peq.  *)
    (* subst id'. unfold code_label in CIMAP. destruct slbl'. inv CIMAP. simpl. admit. *)
    Admitted.


    
Definition def_size (def: AST.globdef Asm.fundef unit) : Z :=
  match def with
  | Gfun (External e) => 1
  | Gfun (Internal f) => Asm.code_size (Asm.fn_code f)
  | Gvar v => AST.init_data_list_size (AST.gvar_init v)
  end.

Lemma update_map_gmap_some :
  forall (prog : Asm.program) (gmap : GID_MAP_TYPE) (lmap : LABEL_MAP_TYPE) (dsize csize efsize : Z) (id : ident)
    defs gdefs def
    (DEFSNAMES: defs_names_distinct (AST.prog_defs prog))
    (UPDATE: update_map prog = OK (gmap, lmap, dsize, csize, efsize))
    (DEFS: (defs ++ (id, Some def) :: gdefs) = AST.prog_defs prog),
    exists slbl, gmap id = Some slbl 
           /\ (forall id' def' slbl', In (id', Some def') defs -> (gmap id' = Some slbl') ->
              fst slbl' = fst slbl -> Ptrofs.unsigned (snd slbl') + def_size def' <= Ptrofs.unsigned (snd slbl)).
Proof.
  (* intros. monadInv UPDATE. *)
  (* set (gvmap := (update_gvars_map {| di_size := 0; di_map := default_gid_map |} (AST.prog_defs prog0))) in *. *)
  (* set (efmap := (update_extfuns_map {| di_size := 0; di_map := di_map gvmap |} (AST.prog_defs prog0))) in *. *)
  (* set (fmap := (update_funs_map {| ci_size := 0; ci_map := di_map efmap; ci_lmap := default_label_map |} (AST.prog_defs prog0))) in *. *)

  (* destruct def. destruct f. *)
  (* def is an internal function *)


  (* exploit (update_map_gmap_some_internal defs {| ci_size := 0; ci_map := di_map efmap; ci_lmap := default_label_map |}); eauto.  *)


  (* rewrite FMAPEQ. unfold fmap'. simpl. *)

  (* Lemma update_funs_map_gmap_shrink : forall defs2 defs1 defs id cinfo, *)
  (*     defs1 ++ defs2 = defs ->   *)
  (*     defs_names_distinct defs -> *)
  (*     In id (map fst defs1) -> *)
  (*     ci_map (update_funs_map cinfo defs) id = ci_map (update_funs_map cinfo defs1) id. *)
  (* Admitted. *)

  (* assert (((defs ++ (id, Some def) :: nil) ++ gdefs) = AST.prog_defs prog0) as DEFS'. *)
  (* { rewrite <- app_assoc. simpl. auto. } *)
  (* assert (In (id, Some def) (defs ++ (id, Some def) :: nil)) as IN. *)
  (* { apply in_app. right. apply in_eq. } *)
  (* assert (In id (map fst (defs ++ (id, Some def) :: nil))) as INID. *)
  (* { replace id with (fst ((id, Some def))) by auto. apply in_map. auto. } *)
  (* exploit (fun a b c d => update_funs_map_gmap_shrink a b c d *)
  (*              {| ci_size := 0; ci_map := di_map efmap; ci_lmap := default_label_map |}); eauto using DEFS', INID. *)
  (* fold fmap. intros FMAPEQ. *)
  (* set (fmap' := (update_funs_map {| ci_size := 0; ci_map := di_map efmap; ci_lmap := default_label_map |} (defs ++ (id, Some def) :: nil))) in *. *)

  (* Lemma update_extfuns_map_gmap_shrink : forall defs2 defs1 defs id dinfo, *)
  (*     defs1 ++ defs2 = defs ->   *)
  (*     defs_names_distinct defs -> *)
  (*     In id (map fst defs1) -> *)
  (*     di_map (update_extfuns_map dinfo defs) id = di_map (update_extfuns_map dinfo defs1) id. *)
  (* Admitted. *)

  (* exploit (fun a b c d => update_extfuns_map_gmap_shrink a b c d *)
  (*              {| di_size := 0; di_map := di_map gvmap |}); eauto using DEFS', INID. *)
  (* fold efmap. intros EFMAPEQ. *)
  (* set (efmap' := (update_extfuns_map {| di_size := 0; di_map := di_map gvmap |} (defs ++ (id, Some def) :: nil))) in *. *)
  
  (* Lemma update_gvars_map_gmap_shrink : forall defs2 defs1 defs id dinfo, *)
  (*     defs1 ++ defs2 = defs ->   *)
  (*     defs_names_distinct defs -> *)
  (*     In id (map fst defs1) -> *)
  (*     di_map (update_gvars_map dinfo defs) id = di_map (update_gvars_map dinfo defs1) id. *)
  (* Admitted. *)
  
  (* exploit (fun a b c d => update_gvars_map_gmap_shrink a b c d *)
  (*              {| di_size := 0; di_map := default_gid_map |}); eauto using DEFS', INID. *)
  (* fold gvmap. intros GVMAPEQ. *)
  (* set (gvmap' := (update_gvars_map {| di_size := 0; di_map := default_gid_map |} (defs ++ (id, Some def) :: nil))) in *. *)
Admitted.
  


Lemma drop_perm_pres_def_frame_inj : forall m1 lo hi m1' b p,
    Mem.drop_perm m1 b lo hi p = Some m1' ->
    def_frame_inj m1 = def_frame_inj m1'.
Proof.
  unfold def_frame_inj. intros.
  apply Mem.drop_perm_stack in H. rewrite H. auto.
Qed.

Lemma transl_fun_inversion : forall gmap lmap id f f',
    transl_fun gmap lmap id f = OK f' ->
    exists slbl, gmap id = Some slbl /\ fn_range f' = mkSegBlock (fst slbl) (snd slbl) Ptrofs.one.
Proof.
  intros gmap lmap id f f' H. monadInvX H.
  destruct zle; monadInv EQ2. simpl. eexists. split; eauto.
Qed.

Lemma partial_genv_invert_symbol_pres : forall defs id def b,
    b <> Globalenvs.Genv.genv_next (partial_genv defs) ->
    Genv.invert_symbol (partial_genv (defs ++ (id, def) :: nil)) b = Genv.invert_symbol (partial_genv defs) b.
Proof.
  intros defs id def b H.
  unfold partial_genv. rewrite Genv.add_globals_app. simpl.
  match goal with
  | [ |- ?a = _ ] => 
    let eq := fresh "EQ" in
    destruct a eqn:eq
  end.
  - apply Genv.invert_find_symbol in EQ. symmetry. apply Genv.find_invert_symbol.
    destruct (ident_eq id i). subst i.
    rewrite find_symbol_add_global_eq in EQ. inv EQ.
    contradiction.
    erewrite find_symbol_add_global_neq in EQ; eauto.
  - symmetry. eapply invert_symbol_add_global_none in EQ; eauto.
Qed.


Lemma partial_genv_next : forall defs def,
    Globalenvs.Genv.genv_next (partial_genv (defs ++ def :: nil)) =
    Pos.succ (Globalenvs.Genv.genv_next (partial_genv defs)).
Proof.
  intros. unfold partial_genv.
  rewrite Genv.add_globals_app. simpl. auto.
Qed.

Lemma defs_names_distinct_not_in : forall (defs:list (ident * option (AST.globdef Asm.fundef unit))) id def gdefs,
    defs_names_distinct (defs ++ (id, def) :: gdefs) -> ~In id (map fst defs).
Proof.
  induction defs. intros.
  - auto.
  - intros id def gdefs H. simpl in H. inv H. rewrite map_app in *.
    simpl in *. destruct a. simpl. unfold not. intros [EQ | OTHER].
    + subst. simpl in H2. rewrite in_app in H2. apply H2. right. apply in_eq.
    + replace (map fst defs ++ id :: map fst gdefs) with
          ((map fst defs ++ (id :: nil)) ++ map fst gdefs) in H3.
      apply list_norepet_append_left in H3.
      apply list_norepet_append_commut in H3. simpl in H3.
      inv H3. congruence.
      rewrite <- app_assoc. simpl. auto.
Qed.

Lemma find_symbol_inversion_1 : forall defs (x : ident) (b : block), 
    Genv.find_symbol (partial_genv defs) x = Some b -> exists def, In (x, def) defs.
Admitted.


Lemma alloc_globals_inject : 
  forall gdefs tgdefs defs m1 m2 m1' gmap lmap  code dsize csize efsize
    (DEFNAMES: defs_names_distinct (AST.prog_defs prog))
    (DEFSTAIL: defs ++ gdefs = AST.prog_defs prog)
    (UPDATE: update_map prog = OK (gmap, lmap, dsize, csize, efsize))
    (TRANSPROG: transl_prog_with_map gmap lmap prog dsize csize efsize = OK tprog)
    (TRANSG: transl_globdefs gmap lmap gdefs = OK (tgdefs, code))
    (MINJ: Mem.inject (globs_meminj defs gmap) (def_frame_inj m1) m1 m1')
    (ALLOCG: Genv.alloc_globals ge m1 gdefs = Some m2)
    (BLOCKEQ : Mem.nextblock m1 = Globalenvs.Genv.genv_next (partial_genv defs))
    (PERMS: forall id b def ofs k p, 
        Genv.find_symbol (partial_genv defs) id = Some b -> 
        In (id, (Some def)) defs -> Mem.perm m1 b ofs k p ->
        ofs < def_size def),
    exists m2', alloc_globals tge (Genv.genv_segblocks tge) m1' tgdefs = Some m2'
           /\ Mem.inject (globs_meminj (AST.prog_defs prog) gmap) (def_frame_inj m2) m2 m2'.
Proof.
  induction gdefs; intros.
  - monadInv TRANSG. inv ALLOCG. rewrite app_nil_r in DEFSTAIL. subst defs.
    simpl. eexists; split; eauto.
  - destruct a. destruct o. 
    + destruct g. destruct f.
      * (** the head of gdefs is an internal function **)
        monadInv TRANSG. destruct x; monadInv EQ. inv EQ2.
        simpl in ALLOCG. destr_match_in ALLOCG; try now inversion ALLOCG.
        destruct (Mem.alloc m1 0 1) eqn:ALLOCF.
        exploit Mem.alloc_result; eauto using ALLOCF. intros.
        exploit update_map_gmap_some; eauto. 
        intros (slbl & GMAP & OFSRANGE).

        (* alloc mapped injection *)
        exploit (Mem.alloc_left_mapped_inject 
                   (globs_meminj defs gmap) (def_frame_inj m1) m1 m1' 0 1 m0
                   b (gen_segblocks tprog (fst slbl)) (Ptrofs.unsigned (snd slbl))
                   MINJ ALLOCF); eauto.
        (* valid block *)
        admit.
        (* valid offset *)
        admit.
        (* the offset of a location with permission is valid *)
        admit.
        (* preservation of permission *)
        admit.
        (* correct alignment *)
        admit.
        (* alloced memory has not been injected before *)
        intros b0 delta' ofs k p GINJ PERM' OFSABSURD.
        unfold globs_meminj in GINJ.
        destr_match_in GINJ; try now inv GINJ.
        destr_match_in GINJ; try now inv GINJ.
        unfold Genv.label_to_block_offset in GINJ. inv GINJ.
        assert (fst s = fst slbl).
        { 
          eapply gen_segblocks_injective; eauto. 
          apply gen_segblocks_in_valid; eauto. 
          eapply AGREE_SMINJ_INSTR.update_map_gmap_range; eauto.
        }
        apply Genv.invert_find_symbol in EQ2.
        exploit find_symbol_inversion_1; eauto. intros (def' & IN).
        destruct def'.
        exploit PERMS; eauto. intros.
        assert (Ptrofs.unsigned (snd s) + def_size g <= Ptrofs.unsigned (snd slbl)).
        { eapply OFSRANGE; eauto. } 
        omega.

        assert (In (i0, None) (AST.prog_defs prog)).
        { rewrite <- DEFSTAIL. rewrite in_app. auto. }
        exploit update_map_gmap_none; eauto. congruence.

        (* allocated memory is public *)
        admit.
        intros (f' & MINJ' & INJINCR & FNB & FINV).
        erewrite alloc_pres_def_frame_inj in MINJ'; eauto.

        (* normalize the resulting inject of alloc *)
        assert (forall x, f' x = (globs_meminj (defs ++ (i, Some (Gfun (Internal f))) :: nil) gmap) x) as INJEQ.
        {
          intros x2. destruct (eq_block x2 b).
          (* x = b *)
          subst x2. unfold globs_meminj.
          generalize (partial_genv_invert_symbol defs i (Some (Gfun (Internal f)))).
          intros INVSYM. subst b. rewrite BLOCKEQ. 
          setoid_rewrite INVSYM. rewrite GMAP. rewrite <- BLOCKEQ. rewrite FNB.
          auto.
          (* x <> b *)
          subst b. exploit FINV; eauto. intros FB. rewrite FB.
          rewrite BLOCKEQ in n. unfold globs_meminj.
          erewrite partial_genv_invert_symbol_pres; eauto.
        }
        exploit (Mem.inject_ext f' (globs_meminj (defs ++ (i, Some (Gfun (Internal f))) :: nil) gmap)); eauto.
        intros MINJ''.

        (* drop_perm injection *)
        exploit Mem.drop_parallel_inject; eauto using MINJ''. 
        red. simpl. auto. rewrite <- INJEQ. eauto.
        intros (m2' & DROP & MINJ''').
        erewrite drop_perm_pres_def_frame_inj in MINJ'''; eauto.

        (* apply the induction hypothesis *)
        assert ((defs ++ (i, Some (Gfun (Internal f))) :: nil) ++ gdefs = AST.prog_defs prog) as DEFSTAIL'.
        rewrite <- DEFSTAIL. rewrite <- app_assoc. simpl. auto.
        exploit (IHgdefs x0 (defs ++ (i, Some (Gfun (Internal f))) :: nil) m); eauto using MINJ''', DEFSTAIL'.
        (* nextblock *)
        erewrite Mem.nextblock_drop; eauto.
        erewrite Mem.nextblock_alloc; eauto. rewrite BLOCKEQ.      
        rewrite partial_genv_next. auto.
        (* perms *)
        intros id b0 def ofs k p FINDSYM IN PERM'.
        rewrite in_app in IN. destruct IN as [IN | IN].

        assert (i <> id). admit.
        erewrite partial_genv_find_symbol_neq in FINDSYM; eauto.
        assert (b <> b0). admit.
        erewrite (drop_perm_perm _ _ _ _ _ _ EQ) in PERM'. destruct PERM' as [PERM' PIN].
        exploit Mem.perm_alloc_inv; eauto using ALLOCF. 
        rewrite dec_eq_false; auto. intros. eapply PERMS; eauto.

        inv IN. inv H0. 
        rewrite partial_genv_find_symbol_eq in FINDSYM. inv FINDSYM.
        rewrite <- BLOCKEQ in PERM'.
        erewrite (drop_perm_perm _ _ _ _ _ _ EQ) in PERM'. destruct PERM' as [PERM' PIN].
        exploit Mem.perm_alloc_inv; eauto using ALLOCF. 
        rewrite dec_eq_true. intros.
        simpl. assert (ofs = 0). omega. subst.
        admit.

        inv H0.

        (* finish this case *)
        intros (m3' & ALLOCG' & MINJ_FINAL).
        exists m3'. split; auto. simpl. 
        exploit transl_fun_inversion; eauto.
        intros (slbl' & GMAP' & FRANGE).
        rewrite GMAP in GMAP'. inv GMAP'. rewrite FRANGE. simpl.
        unfold tge. rewrite genv_gen_segblocks. setoid_rewrite Ptrofs.unsigned_repr.
        rewrite Z.add_comm. setoid_rewrite DROP. auto. admit.

      * (** the head of gdefs is an external function **)
        monadInv TRANSG. destruct (gmap i) eqn:ILBL; try now inversion EQ.
        destruct s. monadInv EQ. monadInv EQ2.
        simpl in ALLOCG. destr_match_in ALLOCG; try now inversion ALLOCG.
        destruct (Mem.alloc m1 0 1) eqn:ALLOCF.
        exploit Mem.alloc_result; eauto using ALLOCF. intros.
        exploit update_map_gmap_some; eauto. 
        intros (slbl & GMAP & OFSRANGE).

        (* alloc mapped injection *)
        exploit (Mem.alloc_left_mapped_inject 
                   (globs_meminj defs gmap) (def_frame_inj m1) m1 m1' 0 1 m0
                   b (gen_segblocks tprog (fst slbl)) (Ptrofs.unsigned (snd slbl))
                   MINJ ALLOCF); eauto.
        (* valid block *)
        admit.
        (* valid offset *)
        admit.
        (* the offset of a location with permission is valid *)
        admit.
        (* preservation of permission *)
        admit.
        (* correct alignment *)
        admit.
        (* alloced memory has not been injected before *)
        intros b0 delta' ofs k p GINJ PERM' OFSABSURD.
        unfold globs_meminj in GINJ.
        destr_match_in GINJ; try now inv GINJ.
        destr_match_in GINJ; try now inv GINJ.
        unfold Genv.label_to_block_offset in GINJ. inv GINJ.
        assert (fst s0 = fst slbl).
        { 
          eapply gen_segblocks_injective; eauto. 
          apply gen_segblocks_in_valid; eauto. 
          eapply AGREE_SMINJ_INSTR.update_map_gmap_range; eauto.
        }
        apply Genv.invert_find_symbol in EQ0.
        exploit find_symbol_inversion_1; eauto. intros (def' & IN).
        destruct def'.
        exploit PERMS; eauto. intros.
        assert (Ptrofs.unsigned (snd s0) + def_size g <= Ptrofs.unsigned (snd slbl)).
        { eapply OFSRANGE; eauto. } 
        omega.

        assert (In (i1, None) (AST.prog_defs prog)).
        { rewrite <- DEFSTAIL. rewrite in_app. auto. }
        exploit update_map_gmap_none; eauto. congruence.

        (* allocated memory is public *)
        admit.
        intros (f' & MINJ' & INJINCR & FNB & FINV).
        erewrite alloc_pres_def_frame_inj in MINJ'; eauto.

        (* normalize the resulting inject of alloc *)
        assert (forall x, f' x = (globs_meminj (defs ++ (i, Some (Gfun (External e))) :: nil) gmap) x) as INJEQ.
        {
          intros x2. destruct (eq_block x2 b).
          (* x = b *)
          subst x2. unfold globs_meminj.
          generalize (partial_genv_invert_symbol defs i (Some (Gfun (External e)))).
          intros INVSYM. subst b. rewrite BLOCKEQ. 
          setoid_rewrite INVSYM. rewrite GMAP. rewrite <- BLOCKEQ. rewrite FNB.
          auto.
          (* x <> b *)
          subst b. exploit FINV; eauto. intros FB. rewrite FB.
          rewrite BLOCKEQ in n. unfold globs_meminj.
          erewrite partial_genv_invert_symbol_pres; eauto.
        }
        exploit (Mem.inject_ext f' (globs_meminj (defs ++ (i, Some (Gfun (External e))) :: nil) gmap)); eauto.
        intros MINJ''.

        (* drop_perm injection *)
        exploit Mem.drop_parallel_inject; eauto using MINJ''. 
        red. simpl. auto. rewrite <- INJEQ. eauto.
        intros (m2' & DROP & MINJ''').
        erewrite drop_perm_pres_def_frame_inj in MINJ'''; eauto.

        (* apply the induction hypothesis *)
        assert ((defs ++ (i, Some (Gfun (External e))) :: nil) ++ gdefs = AST.prog_defs prog) as DEFSTAIL'.
        rewrite <- DEFSTAIL. rewrite <- app_assoc. simpl. auto.
        exploit (IHgdefs x0 (defs ++ (i, Some (Gfun (External e))) :: nil) m); eauto using MINJ''', DEFSTAIL'.
        (* nextblock *)
        erewrite Mem.nextblock_drop; eauto.
        erewrite Mem.nextblock_alloc; eauto. rewrite BLOCKEQ.      
        rewrite partial_genv_next. auto.
        (* perm *)
        intros id b0 def ofs k p FINDSYM IN PERM'.
        rewrite in_app in IN. destruct IN as [IN | IN].

        assert (i <> id). admit.
        erewrite partial_genv_find_symbol_neq in FINDSYM; eauto.
        assert (b <> b0). admit.
        erewrite (drop_perm_perm _ _ _ _ _ _ EQ) in PERM'. destruct PERM' as [PERM' PIN].
        exploit Mem.perm_alloc_inv; eauto using ALLOCF. 
        rewrite dec_eq_false; auto. intros. eapply PERMS; eauto.

        inv IN. inv H0. 
        rewrite partial_genv_find_symbol_eq in FINDSYM. inv FINDSYM.
        rewrite <- BLOCKEQ in PERM'.
        erewrite (drop_perm_perm _ _ _ _ _ _ EQ) in PERM'. destruct PERM' as [PERM' PIN].
        exploit Mem.perm_alloc_inv; eauto using ALLOCF. 
        rewrite dec_eq_true. intros.
        simpl. assert (ofs = 0). omega. subst.
        admit.

        inv H0.

        (* finish this case *)
        intros (m3' & ALLOCG' & MINJ_FINAL).
        exists m3'. split; auto. simpl.
        rewrite GMAP in ILBL. inv ILBL.
        unfold tge. rewrite genv_gen_segblocks. setoid_rewrite Ptrofs.unsigned_repr.
        rewrite Z.add_comm. setoid_rewrite DROP. auto. admit.

      * (** the head of gdefs is a global variable **)
        monadInv TRANSG. destruct (gmap i) eqn:ILBL; try now inversion EQ.
        destruct s. monadInv EQ. monadInv EQ2.
        simpl in ALLOCG. 
        destr_match_in ALLOCG; try now inversion ALLOCG.
        destr_match_in EQ.
        destr_match_in EQ; try now inversion EQ.
        destr_match_in EQ; try now inversion EQ.
        rename EQ2 into ALLOCINIT.
        rename EQ3 into STOREZERO.
        rename EQ4 into STOREINIT.
        rename EQ into DROP.
        exploit Mem.alloc_result; eauto using ALLOCINIT. intros.
        exploit update_map_gmap_some; eauto. 
        intros (slbl & GMAP & OFSRANGE).

        (* alloc mapped injection *)
        exploit (Mem.alloc_left_mapped_inject 
                   (globs_meminj defs gmap) (def_frame_inj m1) m1 m1' 0 (init_data_list_size (gvar_init v)) m0
                   b (gen_segblocks tprog (fst slbl)) (Ptrofs.unsigned (snd slbl))
                   MINJ ALLOCINIT); eauto.
        (* valid block *)
        admit.
        (* valid offset *)
        admit.
        (* the offset of a location with permission is valid *)
        admit.
        (* preservation of permission *)
        admit.
        (* correct alignment *)
        admit.
        (* alloced memory has not been injected before *)
        intros b0 delta' ofs k p GINJ PERM' OFSABSURD.
        unfold globs_meminj in GINJ.
        destr_match_in GINJ; try now inv GINJ.
        destr_match_in GINJ; try now inv GINJ.
        unfold Genv.label_to_block_offset in GINJ. inv GINJ.
        assert (fst s0 = fst slbl).
        { 
          eapply gen_segblocks_injective; eauto. 
          apply gen_segblocks_in_valid; eauto. 
          eapply AGREE_SMINJ_INSTR.update_map_gmap_range; eauto.
        }
        apply Genv.invert_find_symbol in EQ.
        exploit find_symbol_inversion_1; eauto. intros (def' & IN).
        destruct def'.
        exploit PERMS; eauto. intros.
        assert (Ptrofs.unsigned (snd s0) + def_size g <= Ptrofs.unsigned (snd slbl)).
        { eapply OFSRANGE; eauto. } 
        omega.

        assert (In (i1, None) (AST.prog_defs prog)).
        { rewrite <- DEFSTAIL. rewrite in_app. auto. }
        exploit update_map_gmap_none; eauto. congruence.

        (* allocated memory is public *)
        admit.
        intros (f' & MINJ' & INJINCR & FNB & FINV).
        erewrite alloc_pres_def_frame_inj in MINJ'; eauto.

        (* normalize the resulting inject of alloc *)
        assert (forall x, f' x = (globs_meminj (defs ++ (i, Some (Gvar v)) :: nil) gmap) x) as INJEQ.
        {
          intros x. destruct (eq_block x b).
          (* x = b *)
          subst x. unfold globs_meminj.
          generalize (partial_genv_invert_symbol defs i (Some (Gvar v))).
          intros INVSYM. subst b. rewrite BLOCKEQ. 
          setoid_rewrite INVSYM. rewrite GMAP. rewrite <- BLOCKEQ. rewrite FNB.
          auto.
          (* x <> b *)
          subst b. exploit FINV; eauto. intros FB. rewrite FB.
          rewrite BLOCKEQ in n. unfold globs_meminj.
          erewrite partial_genv_invert_symbol_pres; eauto.
        }
        exploit (Mem.inject_ext f' (globs_meminj (defs ++ (i, Some (Gvar v)) :: nil) gmap)); eauto.
        intros MINJ''.

        (* store_zeros injection *)

        Lemma store_zeros_mapped_inject:
          forall (f : meminj) (g : frameinj) (m1 : mem) (b1 : block) (ofs n : Z) 
            (n1 m2 : mem) (b2 : block) (delta : Z),
            Mem.inject f g m1 m2 ->
            store_zeros m1 b1 ofs n = Some n1 ->
            f b1 = Some (b2, delta) ->
            exists n2 : mem, store_zeros m2  b2 (ofs+delta) n = Some n2 /\ Mem.inject f g n1 n2.
        Admitted.

        exploit store_zeros_mapped_inject; eauto.
        rewrite <- INJEQ. rewrite FNB. eauto.
        intros (m2' & STOREZERO' & MINJZ).
        
        Lemma store_zeros_pres_def_frame_inj : forall m1 b lo hi m1',
            store_zeros m1 b lo hi = Some m1' ->
            def_frame_inj m1 = def_frame_inj m1'.
        Admitted.

        erewrite (store_zeros_pres_def_frame_inj m0) in MINJZ; eauto.
        
        (* store_init_data_list inject *)

        Definition init_data_defined (d : AST.init_data) ids : Prop :=
          match d with
          | AST.Init_addrof id _ => In id ids
          | _ => True
          end.

        Definition init_data_list_defined (l: list AST.init_data) ids : Prop :=
          Forall (fun d => init_data_defined d ids) l.
          
        Lemma store_init_data_list_mapped_inject : forall defs gmap g m1 m1' m2 v v' b1 b2 delta ofs,
            Mem.inject (globs_meminj defs gmap) g m1 m1' ->
            init_data_list_defined (AST.gvar_init v) (map fst defs) ->
            transl_gvar gmap v = OK v' -> 
            (globs_meminj defs gmap) b1 = Some (b2, delta) ->
            Genv.store_init_data_list ge m1 b1 ofs (gvar_init v) = Some m2 ->
            exists m2', store_init_data_list tge m1' b2 (ofs+delta) (FlatAsmGlobdef.gvar_init unit v') = Some m2'
                   /\ Mem.inject (globs_meminj defs gmap) g m2 m2'.
        Admitted.

        exploit store_init_data_list_mapped_inject; eauto. admit.
        rewrite <- INJEQ. rewrite FNB. eauto.
        intros (m3' & STOREINIT' & MINJSI).
        
        Lemma store_init_data_list_pres_def_frame_inj : forall m1 b1 ofs gv m1',
            Genv.store_init_data_list ge m1 b1 ofs gv = Some m1' ->
            def_frame_inj m1 = def_frame_inj m1'.
        Admitted.

        erewrite store_init_data_list_pres_def_frame_inj in MINJSI; eauto.
        
        (* dorp_perm inject *)
        exploit Mem.drop_parallel_inject; eauto.
        red. simpl. auto.
        rewrite <- INJEQ. rewrite FNB. eauto.
        intros (m4' & DROP' & MINJDR).
        erewrite drop_perm_pres_def_frame_inj in MINJDR; eauto.
        
        (* apply the induction hypothesis *)
        assert ((defs ++ (i, Some (Gvar v)) :: nil) ++ gdefs = AST.prog_defs prog) as DEFSTAIL'.
        rewrite <- DEFSTAIL. rewrite <- app_assoc. simpl. auto.
        exploit (IHgdefs x0 (defs ++ (i, Some (Gvar v)) :: nil) m); eauto using MINJDR, DEFSTAIL'.
        (* nextblock *)
        erewrite Mem.nextblock_drop; eauto.
        erewrite Genv.store_init_data_list_nextblock; eauto.
        erewrite Genv.store_zeros_nextblock; eauto.
        erewrite Mem.nextblock_alloc; eauto. rewrite BLOCKEQ.      
        rewrite partial_genv_next. auto.
        (* perm *)
        intros id b0 def ofs k p FINDSYM IN PERM'.
        rewrite in_app in IN. destruct IN as [IN | IN].

        assert (i <> id). admit.
        erewrite partial_genv_find_symbol_neq in FINDSYM; eauto.
        assert (b <> b0). admit.
        erewrite (drop_perm_perm _ _ _ _ _ _ DROP) in PERM'. destruct PERM' as [PERM' PIN].
        erewrite <- (Genv.store_init_data_list_perm _ _ _ _ _ _ _ _ _ STOREINIT) in PERM'; eauto.
        erewrite <- (Genv.store_zeros_perm _ _ _ _ _ _ _ _ STOREZERO) in PERM'; eauto.
        exploit Mem.perm_alloc_inv; eauto using ALLOCINIT. 
        rewrite dec_eq_false; auto. intros. eapply PERMS; eauto.

        inv IN. inv H0. 
        rewrite partial_genv_find_symbol_eq in FINDSYM. inv FINDSYM.
        rewrite <- BLOCKEQ in PERM'.
        erewrite (drop_perm_perm _ _ _ _ _ _ DROP) in PERM'. destruct PERM' as [PERM' PIN].
        erewrite <- (Genv.store_init_data_list_perm _ _ _ _ _ _ _ _ _ STOREINIT) in PERM'; eauto.
        erewrite <- (Genv.store_zeros_perm _ _ _ _ _ _ _ _ STOREZERO) in PERM'; eauto.
        exploit Mem.perm_alloc_inv; eauto using ALLOCINIT. 
        rewrite dec_eq_true. intros.
        simpl. omega. 

        inv H0.
        
        (* Finish this case *)
        intros (m5' & ALLOCG' & MINJ_FINAL).
        exists m5'. split; auto. simpl.
        rewrite GMAP in ILBL. inv ILBL.
        unfold tge. rewrite genv_gen_segblocks. 
        
        Lemma transl_gvar_pres_size : forall gmap v v', 
            transl_gvar gmap v = OK v' ->
            (init_data_list_size (gvar_init v)) =
            (FlatAsmGlobdef.init_data_list_size (FlatAsmGlobdef.gvar_init unit v')).
        Admitted.

        erewrite <- transl_gvar_pres_size; eauto.
        setoid_rewrite STOREZERO'.
        unfold tge in STOREINIT'. setoid_rewrite STOREINIT'.
        rewrite Z.add_comm. 

        Lemma transl_gvar_pres_perm : forall gmap v (v':FlatAsmGlobdef.globvar unit), 
            transl_gvar gmap v = OK v' ->
            Genv.perm_globvar v = FlatAsmGlobdef.perm_globvar v'.
        Admitted.

        erewrite <- transl_gvar_pres_perm; eauto.
        setoid_rewrite DROP'. auto.
        
    + (* THE head of gdefs is None *)
      monadInv TRANSG. simpl in ALLOCG.
      set (mz := Mem.alloc m1 0 0) in *. destruct mz eqn:ALLOCZ. subst mz.
      eapply (IHgdefs tgdefs (defs ++ (i, None) :: nil)); eauto.
      rewrite <- DEFSTAIL. rewrite List.app_assoc_reverse. simpl. auto.
      assert (gmap i = None).
      { 
        eapply update_map_gmap_none; eauto. 
        rewrite <- DEFSTAIL. apply in_app. right. apply in_eq.
      }
      exploit Mem.alloc_left_unmapped_inject; eauto using MINJ.
      intros (f & MINJ' & INJINCR & FNONE & FINV).
      erewrite alloc_pres_def_frame_inj in MINJ'; eauto.
      apply Mem.inject_ext with f. auto.
      intros x. destruct (eq_block b x). subst x.
      exploit Mem.alloc_result; eauto using ALLOCZ. intros. subst b.
      unfold globs_meminj. rewrite BLOCKEQ.       
      rewrite partial_genv_invert_symbol. rewrite H. congruence.
      erewrite FINV; eauto. apply globs_meminj_none_pres. auto.
      
      (* next block *)
      unfold partial_genv. rewrite Genv.add_globals_app. simpl.
      exploit Mem.nextblock_alloc; eauto. intros NB. rewrite NB. f_equal.
      rewrite BLOCKEQ. unfold partial_genv. auto.

      (* perm *)
        intros id b0 def ofs k p FINDSYM IN PERM'.
        rewrite in_app in IN. destruct IN as [IN | IN].

        assert (i <> id). admit.
        erewrite partial_genv_find_symbol_neq in FINDSYM; eauto.
        assert (b <> b0). admit.
        exploit Mem.perm_alloc_inv; eauto using ALLOCZ. 
        rewrite dec_eq_false; auto. intros. eapply PERMS; eauto.

        inv IN. inv H. 

        inv H.

Admitted.




Lemma globs_meminj_empty : forall gmap b,
    globs_meminj nil gmap b = None.
Proof. 
  intros gmap b. unfold globs_meminj.
  destruct (Genv.invert_symbol (Genv.globalenv prog) b); auto.
Qed.

Lemma alloc_all_globals_inject : 
  forall tgdefs m2 m1' gmap lmap  code dsize csize efsize
    (DEFNAMES: defs_names_distinct (AST.prog_defs prog))
    (UPDATE: update_map prog = OK (gmap, lmap, dsize, csize, efsize))
    (TRANSPROG: transl_prog_with_map gmap lmap prog dsize csize efsize = OK tprog)
    (TRANSG: transl_globdefs gmap lmap (AST.prog_defs prog) = OK (tgdefs, code))
    (MINJ: Mem.inject (fun _ => None) (def_frame_inj Mem.empty) Mem.empty m1')
    (ALLOCG: Genv.alloc_globals ge Mem.empty (AST.prog_defs prog) = Some m2),
    exists m2', alloc_globals tge (Genv.genv_segblocks tge) m1' tgdefs = Some m2'
           /\ Mem.inject (globs_meminj (AST.prog_defs prog) gmap) (def_frame_inj m2) m2 m2'.
Proof.
  intros. eapply alloc_globals_inject; eauto.
  instantiate (1:=nil). auto. apply Mem.inject_ext with (fun _ => None). auto.
  symmetry. apply globs_meminj_empty.
  simpl. rewrite Mem.nextblock_empty; eauto.
  intros id b def ofs k p FINDSYM IN PERM.
  inv IN.
Qed.

(* Lemma init_mem_pres_inject : forall m m1 m1' f g code gmap lmap dsize csize efsize defs tdefs, *)
(*     update_map prog = OK (gmap, lmap, dsize, csize, efsize) -> *)
(*     transl_globdefs gmap lmap defs = OK (tdefs, code) -> *)
(*     Globalenvs.Genv.alloc_globals ge m1 defs = Some m -> *)
(*     Mem.inject f g m1 m1' -> *)
(*     exists m', Genv.alloc_globals tge m1' tdefs = Some m' *)
(*           /\ Mem.inject (init_meminj gmap) (def_frame_inj m) m m'. *)
(* Proof. *)


Lemma mem_empty_inject: Mem.inject (fun _ : block => None) (def_frame_inj Mem.empty) Mem.empty Mem.empty.
Proof.
  unfold def_frame_inj. apply Mem.self_inject; auto.
  intros. congruence.
Qed.

Lemma initial_inject: (Mem.inject (fun b => None) (def_frame_inj Mem.empty) Mem.empty (fst (Mem.alloc Mem.empty 0 0))).
Proof.
  apply Mem.alloc_right_inject with 
      (m2 := Mem.empty) (lo:=0) (hi:=0) 
      (b2 := snd (Mem.alloc Mem.empty 0 0)).
  apply mem_empty_inject. 
  destruct (Mem.alloc Mem.empty 0 0). simpl. auto.
Qed.

Lemma alloc_segments_inject: forall sl f g m m',
    Mem.inject f g m m' ->
    Mem.inject f g m (alloc_segments m' sl).
Proof.
  induction sl; simpl; intros.
  - auto.
  - destruct (Mem.alloc m' 0 (Ptrofs.unsigned (segsize a))) eqn:ALLOC.
    exploit Mem.alloc_right_inject; eauto.
Qed.

(* Lemma alloc_globvar_inject : forall gmap gvar1 gvar2 j m1 m2 m1' smap gdef1 gdef2 sb id, *)
(*     transl_gvar gmap gvar1 = OK gvar2 -> *)
(*     Mem.inject j (def_frame_inj m1) m1 m1' -> *)
(*     Genv.alloc_global ge m1 (id, Some gdef1) = Some m2 -> *)
(*     exists j' m2', alloc_global tge smap m1' (id, Some gdef2, sb) = Some m2'  *)
(*               /\ Mem.inject j' (def_frame_inj m2) m2 m2'. *)

(* Lemma alloc_global_inject : forall j m1 m2 m1' gmap smap gdef1 gdef2 sb id, *)
(*     Mem.inject j (def_frame_inj m1) m1 m1' -> *)
(*     Genv.alloc_global ge m1 (id, Some gdef1) = Some m2 -> *)
(*     exists m2', alloc_global tge smap m1' (id, Some gdef2, sb) = Some m2'  *)
(*               /\ Mem.inject (init_meminj gmap) (def_frame_inj m2) m2 m2'. *)
(* Proof. *)
(*   intros. destruct gdef1. destruct f. simpl in H0. *)
(*   Admitted. *)

Lemma alloc_global_ext : forall f1 f2 ge m def,
    (forall x, f1 x = f2 x) -> alloc_global ge f1 m def = alloc_global ge f2 m def.
Proof.
  intros f1 f2 ge0 m def H.
  destruct def. destruct p. destruct o. destruct g.
  - simpl. rewrite (H (segblock_id s)). auto.
  - simpl. rewrite (H (segblock_id s)). auto.
  - simpl. auto.
Qed.

Lemma alloc_globals_ext : forall defs f1 f2 ge m,
    (forall x, f1 x = f2 x) -> alloc_globals ge f1 m defs = alloc_globals ge f2 m defs.
Proof.
  induction defs. intros.
  - simpl. auto.
  - intros f1 f2 ge0 m H. simpl. erewrite alloc_global_ext; eauto. 
    destr_match. erewrite IHdefs; eauto. auto.
Qed.

Lemma init_mem_pres_inject : forall m gmap lmap dsize csize efsize
    (UPDATE: update_map prog = OK (gmap, lmap, dsize, csize, efsize))
    (TRANSPROG: transl_prog_with_map gmap lmap prog dsize csize efsize = OK tprog)
    (INITMEM: Genv.init_mem prog = Some m),
    exists m', init_mem tprog = Some m' /\ Mem.inject (globs_meminj (AST.prog_defs prog) gmap) (def_frame_inj m) m m'. 
Proof. 
  unfold Genv.init_mem, init_mem. intros.
  generalize initial_inject. intros INITINJ.
  destruct (Mem.alloc Mem.empty 0 0) eqn:IALLOC. simpl in INITINJ.
  exploit (alloc_segments_inject (list_of_segments tprog) (fun _ => None)); eauto.
  intros SINJ.
  set (m1 := alloc_segments m0 (list_of_segments tprog)) in *.
  generalize TRANSF. intros TRANSF'. unfold match_prog in TRANSF'.
  unfold transf_program in TRANSF'.
  destruct (check_wellformedness prog) eqn:WF; monadInv TRANSF'.
  destruct x. destruct p. destruct p. destruct p.
  destruct zle; try now monadInv EQ0. unfold transl_prog_with_map in EQ0.
  destruct (transl_globdefs g l (AST.prog_defs prog)) eqn:TRANSGLOBS; try now inv EQ0.
  simpl in EQ0. destruct p. inversion EQ0. clear EQ0. rewrite H0.
  rewrite UPDATE in EQ. inversion EQ. subst g l z1 z0 z.
  exploit alloc_all_globals_inject; eauto using INITMEM, SINJ, Mem.inject_ext, globs_meminj_empty.
  unfold check_wellformedness in WF.
  repeat rewrite andb_true_iff in WF. destruct WF as (FNONEMPTY & NODUPDEFS & NODUPLBLS).
  apply nodup_defs_distinct_names. auto.
  simpl. intros (m1' & ALLOC' & MINJ). 
  exists m1'. split. 
  erewrite (fun defs => alloc_globals_ext defs (gen_segblocks tprog) (Genv.genv_segblocks tge)). 
  subst tprog tge. auto.
  intros x. subst tge. rewrite genv_gen_segblocks. auto.
  auto.
Qed.


Lemma find_funct_ptr_next :
  Genv.find_funct_ptr ge (Globalenvs.Genv.genv_next ge) = None.
Proof.
  unfold Globalenvs.Genv.find_funct_ptr. 
  destruct (Genv.find_def ge (Globalenvs.Genv.genv_next ge)) eqn:EQ; auto.
  destruct g; auto.
  unfold Genv.find_def in EQ.
  apply Globalenvs.Genv.genv_defs_range in EQ.
  exploit Plt_strict; eauto. contradiction.
Qed.

Lemma match_sminj_incr : forall gmap lmap j j',
    (forall b, b <> Globalenvs.Genv.genv_next ge -> j' b = j b) ->
    inject_incr j j' ->
    match_sminj gmap lmap j -> match_sminj gmap lmap j'.
Proof.
  intros gmap lmap j j' INJINV INJINCR MSMINJ. constructor.
  - intros b b' f ofs ofs' i FINDPTR FINDINSTR J.
    eapply (agree_sminj_instr gmap lmap j MSMINJ); eauto. 
    exploit (INJINV b).
    unfold not. intros. 
    subst b. rewrite find_funct_ptr_next in FINDPTR. congruence.
    intros. congruence.

  - intros id gloc H. 
    exploit (agree_sminj_glob gmap lmap j MSMINJ); eauto. 
    intros (ofs' & b & b' & FSYM & SYMADDR & MAP).
    exists ofs', b, b'. split; auto. 

  - intros id b f l z l' FSYM FPTR LPOS LMAP.
    exploit (agree_sminj_lbl gmap lmap j MSMINJ); eauto.
Qed.

Lemma push_new_stage_def_frame_inj : forall m,
    def_frame_inj (Mem.push_new_stage m) = (1%nat :: def_frame_inj m).
Proof.
  unfold def_frame_inj. intros.
  erewrite Mem.push_new_stage_stack. simpl. auto.
Qed.

(* Lemma drop_perm_parallel_inject : forall m1 m2 b lo hi p f b' delta m1' g, *)
(*     Mem.drop_perm m1 b lo hi p = Some m2 -> *)
(*     Mem.inject f g m1 m1' -> *)
(*     f b = Some (b', delta) ->  *)
(*     exists m2', Mem.drop_perm m1' b' (lo+delta) (hi+delta) p = Some m2' *)
(*            /\ Mem.inject f g m2 m2'. *)
(* Admitted. *)

Lemma init_mem_stack:
  forall (p: program) m,
    init_mem p = Some m ->
    Mem.stack m = nil.
Proof.
Admitted.

Lemma init_mem_genv_next: forall p m,
  init_mem p = Some m ->
  Genv.genv_next (globalenv p) = Mem.nextblock m.
Admitted.

Lemma init_meminj_genv_next_inv : forall gmap lmap dsize csize efsize b  delta,
    update_map prog = OK (gmap, lmap, dsize, csize, efsize) ->
    init_meminj gmap b = Some (Genv.genv_next tge, delta) ->
    b = Globalenvs.Genv.genv_next ge.
Admitted.

Lemma transf_initial_states : forall rs st1,
    RawAsm.initial_state prog rs st1  ->
    exists st2, FlatAsm.initial_state tprog rs st2 /\ match_states st1 st2.
Proof.
  intros rs st1 INIT.
  generalize TRANSF. intros TRANSF'.
  unfold match_prog in TRANSF'. unfold transf_program in TRANSF'.
  destruct (check_wellformedness prog) eqn:WF; monadInv TRANSF'.
  destruct x. destruct p. destruct p. destruct p.
  destruct zle; inv EQ0.
  rename g into gmap.
  rename l into lmap.
  rename z1 into dsize. rename z0 into csize. rename z into efsize.
  inv INIT.
  exploit init_meminj_match_sminj; eauto.
  intros MATCH_SMINJ.
  exploit (init_mem_pres_inject m gmap); eauto.
  intros (m' & INITM' & MINJ).
  inversion H1.
  (* push_new stage *)
  exploit Mem.push_new_stage_inject; eauto. intros NSTGINJ.
  exploit (Mem.alloc_parallel_inject (globs_meminj (AST.prog_defs prog) gmap) (1%nat :: def_frame_inj m)
          (Mem.push_new_stage m) (Mem.push_new_stage m')
          0 Mem.stack_limit m1 bstack 0 Mem.stack_limit); eauto. omega. omega.
  intros (j' & m1' & bstack' & MALLOC' & AINJ & INCR & FBSTACK & NOTBSTK).
  rewrite <- push_new_stage_def_frame_inj in AINJ.
  erewrite alloc_pres_def_frame_inj in AINJ; eauto.
  assert (bstack = Globalenvs.Genv.genv_next ge). 
  { 
    exploit (Genv.init_mem_genv_next prog m); eauto. intros BEQ. unfold ge. rewrite BEQ.
    apply Mem.alloc_result in MALLOC; eauto.
    subst bstack. apply Mem.push_new_stage_nextblock.
  }
  assert (bstack' = Genv.genv_next tge). 
  {
    exploit init_mem_genv_next; eauto. intros BEQ.
    unfold tge. rewrite BEQ.
    exploit Mem.alloc_result; eauto.
    intros. subst. apply Mem.push_new_stage_nextblock.
  }
  assert (forall x, j' x = init_meminj gmap x).
  {
    intros. destruct (eq_block x bstack).
    subst x. rewrite FBSTACK. unfold init_meminj. subst.
    rewrite dec_eq_true; auto.
    erewrite NOTBSTK; eauto.
    unfold init_meminj. subst. 
    rewrite dec_eq_false; auto.
    Lemma genv_partial_genv_eq : forall prog,
      partial_genv (AST.prog_defs prog) = Genv.globalenv prog.
    Admitted.
    unfold globs_meminj. rewrite genv_partial_genv_eq. 
    unfold Genv.symbol_block_offset, Genv.label_to_block_offset.
    destruct (Genv.invert_symbol (Genv.globalenv prog) x) eqn:INVSYM; try auto.
    destruct (gmap i) eqn:GMAP; try auto.
    rewrite genv_gen_segblocks. auto.
  }
  exploit Mem.inject_ext; eauto. intros MINJ'.
  exploit Mem.drop_parallel_inject; eauto. red. simpl. auto.
  rewrite <- H5. rewrite FBSTACK. eauto.
  intros (m2' & MDROP' & DMINJ). simpl in MDROP'. rewrite Z.add_0_r in MDROP'.
  erewrite (drop_perm_pres_def_frame_inj m1) in DMINJ; eauto.
  
  assert (exists m3', Mem.record_stack_blocks m2' (make_singleton_frame_adt' bstack' frame_info_mono 0) = Some m3'
                 /\ Mem.inject (init_meminj gmap) (def_frame_inj m3) m3 m3') as RCD.
  {
    unfold def_frame_inj. unfold def_frame_inj in DMINJ.
    eapply (Mem.record_stack_block_inject_flat m2 m3 m2' (init_meminj gmap)
           (make_singleton_frame_adt' bstack frame_info_mono 0)); eauto.
    (* frame inject *)
    red. unfold make_singleton_frame_adt'. simpl. constructor. 
    simpl. intros b2 delta FINJ. rewrite <- H5 in FINJ. 
    rewrite FBSTACK in FINJ. inv FINJ.
    exists frame_info_mono. split. auto. apply inject_frame_info_id.
    constructor.
    (* in frame *)
    unfold make_singleton_frame_adt'. simpl. unfold in_frame. simpl.
    repeat rewrite_stack_blocks. 
    erewrite init_mem_stack; eauto.
    (* valid frame *)
    unfold make_singleton_frame_adt'. simpl. red. unfold in_frame.
    simpl. intuition. subst. 
    eapply Mem.drop_perm_valid_block_1; eauto.
    eapply Mem.valid_new_block; eauto.
    (* frame_agree_perms *)
    red. unfold make_singleton_frame_adt'. simpl. 
    intros b fi o k p BEQ PERM. inv BEQ; try contradiction.
    inv H6. unfold frame_info_mono. simpl.
    erewrite drop_perm_perm in PERM; eauto. destruct PERM.
    eapply Mem.perm_alloc_3; eauto.
    (* in frame iff *)
    unfold make_singleton_frame_adt'. unfold in_frame. simpl.
    intros b1 b2 delta INJB. split.
    intros BEQ. destruct BEQ; try contradiction. subst b1. 
    rewrite <- H5 in INJB.
    rewrite INJB in FBSTACK; inv FBSTACK; auto.
    intros BEQ. destruct BEQ; try contradiction. subst b2. 
    assert (bstack' = Mem.nextblock (Mem.push_new_stage m')) as BEQ. 
    eapply Mem.alloc_result; eauto using MALLOC'.
    rewrite Mem.push_new_stage_nextblock in BEQ.
    erewrite <- init_mem_genv_next in BEQ; eauto using INITM'.
    subst bstack'.     
    destruct (eq_block bstack b1); auto.
    assert (b1 <> bstack) by congruence.
    apply NOTBSTK in H4. rewrite H5 in H4. 
    left. symmetry. subst bstack. eapply init_meminj_genv_next_inv; eauto.

    (* top frame *)
    red. repeat rewrite_stack_blocks. constructor. auto.
    (* size stack *)
    repeat rewrite_stack_blocks. 
    erewrite init_mem_stack; eauto. simpl. omega.
  }

  destruct RCD as (m3' & RCDSB & RMINJ).
  set (rs0' := rs # PC <- (get_main_fun_ptr tge tprog)
                  # RA <- Vnullptr
                  # RSP <- (Vptr bstack' (Ptrofs.repr Mem.stack_limit))) in *.
  exists (State rs0' m3'). split.
  - eapply initial_state_intro; eauto.
    eapply initial_state_gen_intro; eauto.
  - eapply match_states_intro; eauto.
    admit.
    admit.
    admit.
    admit.
    admit.
    admit.
  
Admitted.

Context `{external_calls_ops : !ExternalCallsOps mem }.
Context `{!EnableBuiltins mem}.
Existing Instance Asm.mem_accessors_default.
Existing Instance FlatAsm.mem_accessors_default.

Lemma eval_builtin_arg_inject : forall gm lm j m m' rs rs' sp sp' arg varg arg',
    match_sminj gm lm j ->
    gid_map_for_undef_syms gm ->
    Mem.inject j (def_frame_inj m) m m' ->
    regset_inject j rs rs' ->
    Val.inject j sp sp' ->
    transl_builtin_arg gm arg = OK arg' ->
    eval_builtin_arg ge rs sp m arg varg ->
    exists varg', FlatAsmBuiltin.eval_builtin_arg _ _ preg tge rs' sp' m' arg' varg' /\
             Val.inject j varg varg'.
Proof.
  unfold regset_inject. 
  induction arg; intros; inv H5;
    try (eexists; split; auto; monadInv H4; constructor).
  - monadInv H4. exploit Mem.loadv_inject; eauto.
    eapply Val.offset_ptr_inject; eauto.
    intros (v2 & MVLOAD & LINJ).
    eexists; split; eauto.
    constructor; auto.
  - monadInv H4. 
    exists (Val.offset_ptr sp' ofs). split; try (eapply Val.offset_ptr_inject; eauto).
    constructor.
  - monadInvX H4. unfold Senv.symbol_address in H10.
    destruct (Senv.find_symbol ge id) eqn:FINDSYM.
    + inv H. exploit agree_sminj_glob0; eauto. 
      intros (ofs' & b0 & b' & FSYM & GLOFS & JB).
      unfold Senv.find_symbol in FINDSYM. simpl in FINDSYM. rewrite FSYM in FINDSYM; inv FINDSYM.
      exploit Mem.loadv_inject; eauto.
      intros (varg' & LOADV & VARGINJ).
      exists varg'. split; auto.
      eapply FlatAsmBuiltin.eval_BA_loadglobal.       
      exploit Genv.symbol_address_offset; eauto. intros SYMADDR.
      rewrite SYMADDR. rewrite Ptrofs.repr_unsigned in *.
      rewrite Ptrofs.add_commut. auto.
    + simpl in H10. congruence.
  - monadInvX H4. unfold Senv.symbol_address.
    destruct (Senv.find_symbol ge id) eqn:FINDSYM.
    + inv H. exploit agree_sminj_glob0; eauto. 
      intros (ofs' & b0 & b' & FSYM & GLOFS & JB).
      unfold Senv.find_symbol in FINDSYM. simpl in FINDSYM. rewrite FSYM in FINDSYM; inv FINDSYM.
      eexists. split. 
      apply FlatAsmBuiltin.eval_BA_addrglobal.
      exploit Genv.symbol_address_offset; eauto. intros SYMADDR.
      rewrite SYMADDR.
      eapply Val.inject_ptr; eauto.
      rewrite Ptrofs.repr_unsigned. rewrite Ptrofs.add_commut. auto.
    + unfold Senv.find_symbol in FINDSYM. simpl in FINDSYM.
      unfold gid_map_for_undef_syms in *. exploit H0; eauto.
      congruence.
  - monadInv H4.
    exploit IHarg1; eauto. intros (vhi' & EVAL1 & VINJ1).
    exploit IHarg2; eauto. intros (vlo' & EVAL2 & VINJ2).
    exists (Val.longofwords vhi' vlo'); split.
    + constructor; auto.
    + apply Val.longofwords_inject; eauto.
Qed.

Lemma eval_builtin_args_inject : forall gm lm j m m' rs rs' sp sp' args vargs args',
    match_sminj gm lm j ->
    gid_map_for_undef_syms gm ->
    Mem.inject j (def_frame_inj m) m m' ->
    regset_inject j rs rs' ->
    Val.inject j sp sp' ->
    transl_builtin_args gm args = OK args' ->
    eval_builtin_args ge rs sp m args vargs ->
    exists vargs', FlatAsmBuiltin.eval_builtin_args _ _ preg tge rs' sp' m' args' vargs' /\
             Val.inject_list j vargs vargs'.
Proof.
  induction args; intros; simpl. 
  - inv H4. inv H5. exists nil. split; auto.
    unfold FlatAsmBuiltin.eval_builtin_args. apply list_forall2_nil.
  - monadInv H4. inv H5.
    exploit eval_builtin_arg_inject; eauto. 
    intros (varg' & EVARG & VINJ).
    exploit IHargs; eauto. 
    intros (vargs' & EVARGS & VSINJ).
    exists (varg' :: vargs'). split; auto.
    unfold FlatAsmBuiltin.eval_builtin_args. 
    apply list_forall2_cons; auto.
Qed.

Lemma extcall_arg_inject : forall rs1 rs2 m1 m2 l arg1 j,
    extcall_arg rs1 m1 l arg1 ->
    Mem.inject j (def_frame_inj m1) m1 m2 ->
    regset_inject j rs1 rs2 ->
    exists arg2,
      Val.inject j arg1 arg2 /\
      extcall_arg rs2 m2 l arg2.
Proof.
  intros. inv H.
  - unfold regset_inject in *.
    specialize (H1 (Asm.preg_of r)). eexists; split; eauto.
    constructor.
  - exploit Mem.loadv_inject; eauto.
    apply Val.offset_ptr_inject. apply H1.
    intros (arg2 & MLOADV & ARGINJ).
    exists arg2. split; auto.
    eapply extcall_arg_stack; eauto.
Qed.

Lemma extcall_arg_pair_inject : forall rs1 rs2 m1 m2 lp arg1 j,
    extcall_arg_pair rs1 m1 lp arg1 ->
    Mem.inject j (def_frame_inj m1) m1 m2 ->
    regset_inject j rs1 rs2 ->
    exists arg2,
      Val.inject j arg1 arg2 /\
      extcall_arg_pair rs2 m2 lp arg2.
Proof.
  intros. inv H.
  - exploit extcall_arg_inject; eauto. 
    intros (arg2 & VINJ & EXTCALL).
    exists arg2. split; auto. constructor. auto.
  - exploit (extcall_arg_inject rs1 rs2 m1 m2 hi vhi); eauto. 
    intros (arghi & VINJHI & EXTCALLHI).
    exploit (extcall_arg_inject rs1 rs2 m1 m2 lo vlo); eauto. 
    intros (arglo & VINJLO & EXTCALLLO).
    exists (Val.longofwords arghi arglo). split.
    + apply Val.longofwords_inject; auto.
    + constructor; auto.
Qed.

Lemma extcall_arguments_inject_aux : forall rs1 rs2 m1 m2 locs args1 j,
   list_forall2 (extcall_arg_pair rs1 m1) locs args1 ->
    Mem.inject j (def_frame_inj m1) m1 m2 ->
    regset_inject j rs1 rs2 ->
    exists args2,
      Val.inject_list j args1 args2 /\
      list_forall2 (extcall_arg_pair rs2 m2) locs args2.
Proof.
  induction locs; simpl; intros; inv H.
  - exists nil. split.
    + apply Val.inject_list_nil.
    + unfold Asm.extcall_arguments. apply list_forall2_nil.
  - exploit extcall_arg_pair_inject; eauto.
    intros (arg2 & VINJARG2 & EXTCALLARG2).
    exploit IHlocs; eauto.
    intros (args2 & VINJARGS2 & EXTCALLARGS2).
    exists (arg2 :: args2). split; auto.
    apply list_forall2_cons; auto.
Qed.

Lemma extcall_arguments_inject : forall rs1 rs2 m1 m2 ef args1 j,
    Asm.extcall_arguments rs1 m1 (ef_sig ef) args1 ->
    Mem.inject j (def_frame_inj m1) m1 m2 ->
    regset_inject j rs1 rs2 ->
    exists args2,
      Val.inject_list j args1 args2 /\
      Asm.extcall_arguments rs2 m2 (ef_sig ef) args2.
Proof.
  unfold Asm.extcall_arguments. intros.
  eapply extcall_arguments_inject_aux; eauto.
Qed.

Axiom external_call_inject : forall j vargs1 vargs2 m1 m2 m1' vres1 t ef,
    Val.inject_list j vargs1 vargs2 ->
    Mem.inject j (def_frame_inj m1) m1 m2 ->
    external_call ef ge vargs1 m1 t vres1 m1' ->
    exists j' vres2 m2',
      external_call ef dummy_senv vargs2 m2 t vres2 m2' /\ 
      Val.inject j' vres1 vres2 /\ Mem.inject j' (def_frame_inj m1') m1' m2' /\
      inject_incr j j' /\
      inject_separated j j' m1 m2.

Axiom  external_call_valid_block: forall ef ge vargs m1 t vres m2 b,
    external_call ef ge vargs m1 t vres m2 -> Mem.valid_block m1 b -> Mem.valid_block m2 b.

Lemma extcall_pres_glob_block_valid : forall ef ge vargs m1 t vres m2,
  external_call ef ge vargs m1 t vres m2 -> glob_block_valid m1 -> glob_block_valid m2.
Proof.
  unfold glob_block_valid in *. intros.
  eapply external_call_valid_block; eauto.
Qed.

Lemma regset_inject_incr : forall j j' rs rs',
    regset_inject j rs rs' ->
    inject_incr j j' ->
    regset_inject j' rs rs'.
Proof.
  unfold inject_incr, regset_inject. intros.
  specialize (H r).
  destruct (rs r); inversion H; subst; auto.
  eapply Val.inject_ptr. apply H0. eauto. auto.
Qed.

Lemma undef_regs_pres_inject : forall j rs rs' regs,
  regset_inject j rs rs' ->
  regset_inject j (Asm.undef_regs regs rs) (Asm.undef_regs regs rs').
Proof.
  unfold regset_inject. intros. apply val_inject_undef_regs.
  auto.
Qed.    
  
Lemma Pregmap_gsspec_alt : forall (A : Type) (i j : Pregmap.elt) (x : A) (m : Pregmap.t A),
    (m # j <- x) i  = (if Pregmap.elt_eq i j then x else m i).
Proof.
  intros. apply Pregmap.gsspec.
Qed.

Lemma regset_inject_expand : forall j rs1 rs2 v1 v2 r,
  regset_inject j rs1 rs2 ->
  Val.inject j v1 v2 ->
  regset_inject j (rs1 # r <- v1) (rs2 # r <- v2).
Proof.
  intros. unfold regset_inject. intros.
  repeat rewrite Pregmap_gsspec_alt. 
  destruct (Pregmap.elt_eq r0 r); auto.
Qed.

Lemma regset_inject_expand_vundef_left : forall j rs1 rs2 r,
  regset_inject j rs1 rs2 ->
  regset_inject j (rs1 # r <- Vundef) rs2.
Proof.
  intros. unfold regset_inject. intros.
  rewrite Pregmap_gsspec_alt. destruct (Pregmap.elt_eq r0 r); auto.
Qed.

Lemma set_res_pres_inject : forall res j rs1 rs2,
    regset_inject j rs1 rs2 ->
    forall vres1 vres2,
    Val.inject j vres1 vres2 ->
    regset_inject j (set_res res vres1 rs1) (set_res res vres2 rs2).
Proof.
  induction res; auto; simpl; unfold regset_inject; intros.
  - rewrite Pregmap_gsspec_alt. destruct (Pregmap.elt_eq r x); subst.
    + rewrite Pregmap.gss. auto.
    + rewrite Pregmap.gso; auto.
  - exploit (Val.hiword_inject j vres1 vres2); eauto. intros. 
    exploit (Val.loword_inject j vres1 vres2); eauto. intros.
    apply IHres2; auto.
Qed.


Lemma nextinstr_pres_inject : forall j rs1 rs2 sz,
    regset_inject j rs1 rs2 ->
    regset_inject j (nextinstr rs1 sz) (nextinstr rs2 sz).
Proof.
  unfold nextinstr. intros. apply regset_inject_expand; auto.
  apply Val.offset_ptr_inject. auto.
Qed.  

Lemma nextinstr_nf_pres_inject : forall j rs1 rs2 sz,
    regset_inject j rs1 rs2 ->
    regset_inject j (nextinstr_nf rs1 sz) (nextinstr_nf rs2 sz).
Proof.
  intros. apply nextinstr_pres_inject.
  apply undef_regs_pres_inject. auto.
Qed. 


Lemma set_pair_pres_inject : forall j rs1 rs2 v1 v2 loc,
    regset_inject j rs1 rs2 ->
    Val.inject j v1 v2 ->
    regset_inject j (set_pair loc v1 rs1) (set_pair loc v2 rs2).
Proof.
  intros. unfold set_pair, Asm.set_pair. destruct loc; simpl.
  - apply regset_inject_expand; auto.
  - apply regset_inject_expand; auto.
    apply regset_inject_expand; auto.
    apply Val.hiword_inject; auto.
    apply Val.loword_inject; auto.
Qed.

Lemma vinject_pres_not_vundef : forall j v1 v2,
  Val.inject j v1 v2 -> v1 <> Vundef -> v2 <> Vundef.
Proof.
  intros. destruct v1; inversion H; subst; auto.
  congruence.
Qed.

Lemma vinject_pres_has_type : forall j v1 v2 t,
    Val.inject j v1 v2 -> v1 <> Vundef ->
    Val.has_type v1 t -> Val.has_type v2 t.
Proof.
  intros. destruct v1; inversion H; subst; simpl in H; auto. 
  congruence.
Qed.

Lemma inject_decr : forall b j j' m1 m2 b' ofs,
  Mem.valid_block m1 b -> inject_incr j j' -> inject_separated j j' m1 m2 ->
  j' b = Some (b', ofs) -> j b = Some (b', ofs).
Proof.
  intros. destruct (j b) eqn:JB.
  - unfold inject_incr in *. destruct p. exploit H0; eauto.
    intros. congruence.
  - unfold inject_separated in *. exploit H1; eauto.
    intros (NVALID1 & NVALID2). congruence.
Qed.

Lemma inject_pres_match_sminj : 
  forall j j' m1 m2 gm lm (ms: match_sminj gm lm j), 
    glob_block_valid m1 -> inject_incr j j' -> inject_separated j j' m1 m2 -> 
    match_sminj gm lm j'.
Proof.
  unfold glob_block_valid.
  intros. inversion ms. constructor; intros.
  - 
    eapply (agree_sminj_instr0 b b'); eauto.
    unfold Genv.find_funct_ptr in H2. destruct (Genv.find_def ge b) eqn:FDEF; try congruence.
    exploit H; eauto. intros.
    eapply inject_decr; eauto.
  - 
    exploit agree_sminj_glob0; eauto. 
    intros (ofs' & b0 & b' & FSYM & GLBL & JB).
    eexists; eexists; eexists; eauto.
  - 
    exploit agree_sminj_lbl0; eauto.
Qed.

(* Lemma inject_pres_globs_inj_into_flatmem : forall j j' m1 m2, *)
(*     glob_block_valid m1 -> inject_incr j j' -> inject_separated j j' m1 m2 ->  *)
(*     globs_inj_into_flatmem j -> globs_inj_into_flatmem j'. *)
(* Proof. *)
(*   unfold globs_inj_into_flatmem, glob_block_valid. intros. *)
(*   exploit H; eauto. intros. *)
(*   assert (j b = Some (b', ofs')) by (eapply inject_decr; eauto). *)
(*   eapply H2; eauto. *)
(* Qed. *)


Lemma inject_pres_valid_instr_offset_is_internal : forall j j' m1 m2,
    glob_block_valid m1 -> inject_incr j j' -> inject_separated j j' m1 m2 -> 
    valid_instr_offset_is_internal j -> valid_instr_offset_is_internal j'.
Proof.
  unfold glob_block_valid.
  unfold valid_instr_offset_is_internal. intros.
  eapply H2; eauto.
  unfold Genv.find_funct_ptr in H3. destruct (Genv.find_def ge b) eqn:FDEF; try congruence.
  exploit H; eauto. intros.
  eapply inject_decr; eauto.
Qed.

Lemma inject_pres_extfun_entry_is_external : forall j j' m1 m2,
    glob_block_valid m1 -> inject_incr j j' -> inject_separated j j' m1 m2 -> 
    extfun_entry_is_external j -> extfun_entry_is_external j'.
Proof.
  unfold glob_block_valid.
  unfold extfun_entry_is_external. intros.
  eapply H2; eauto.
  unfold Genv.find_funct_ptr in H3. destruct (Genv.find_def ge b) eqn:FDEF; try congruence.
  exploit H; eauto. intros.
  eapply inject_decr; eauto.
Qed.

Lemma inject_pres_match_find_funct : forall j j' m1 m2,
    glob_block_valid m1 -> inject_incr j j' -> inject_separated j j' m1 m2 -> 
    match_find_funct j -> match_find_funct j'.
Proof.
  unfold glob_block_valid, match_find_funct. intros.
  eapply H2; eauto.
  unfold Genv.find_funct_ptr in H3. destruct (Genv.find_def ge b) eqn:FDEF; try congruence.
  exploit H; eauto. intros.
  eapply inject_decr; eauto.
Qed.  

Remark mul_inject:
  forall f v1 v1' v2 v2',
  Val.inject f v1 v1' ->
  Val.inject f v2 v2' ->
  Val.inject f (Val.mul v1 v2) (Val.mul v1' v2').
Proof.
  intros. unfold Val.mul. destruct v1, v2; simpl; auto.
  inversion H; inversion H0; subst. auto.
Qed.

Remark mull_inject:
  forall f v1 v1' v2 v2',
  Val.inject f v1 v1' ->
  Val.inject f v2 v2' ->
  Val.inject f (Val.mull v1 v2) (Val.mull v1' v2').
Proof.
Proof.
  intros. unfold Val.mull. destruct v1, v2; simpl; auto.
  inversion H; inversion H0; subst. auto.
Qed.

Remark mulhs_inject:
  forall f v1 v1' v2 v2',
  Val.inject f v1 v1' ->
  Val.inject f v2 v2' ->
  Val.inject f (Val.mulhs v1 v2) (Val.mulhs v1' v2').
Proof.
  intros. unfold Val.mulhs. destruct v1, v2; simpl; auto.
  inversion H; inversion H0; subst. auto.
Qed.


Lemma inject_symbol_sectlabel : forall gm lm j id lbl ofs,
    match_sminj gm lm j ->
    gm id = Some lbl ->
    Val.inject j (Globalenvs.Genv.symbol_address ge id ofs) (Genv.symbol_address tge lbl ofs).
Proof.
  unfold Globalenvs.Genv.symbol_address.
  intros.
  destruct (Genv.find_symbol ge id) eqn:FINDSYM; auto.
  inv H. exploit agree_sminj_glob0; eauto.
  intros (ofs' & b0 & b' & FSYM & SBOFS & JB).  
  rewrite FSYM in FINDSYM; inv FINDSYM.
  exploit Genv.symbol_address_offset; eauto. intro SYMADDR. rewrite SYMADDR.
  eapply Val.inject_ptr. eauto.
  rewrite Ptrofs.repr_unsigned. apply Ptrofs.add_commut.
Qed.

Lemma add_undef : forall v,
  Val.add v Vundef = Vundef.
Proof.
  intros; destruct v; simpl; auto.
Qed.

Lemma addl_undef : forall v,
  Val.addl v Vundef = Vundef.
Proof.
  intros; destruct v; simpl; auto.
Qed.

Ltac simpl_goal :=
  repeat match goal with
         | [ |- context [ Int.add Int.zero _ ] ] =>
           rewrite Int.add_zero_l
         | [ |- context [ Int64.add Int64.zero _ ] ] =>
           rewrite Int64.add_zero_l
         | [ |- context [Ptrofs.add _ (Ptrofs.of_int Int.zero)] ] =>
           rewrite Ptrofs.add_zero
         | [ |- context [Ptrofs.add _ (Ptrofs.of_int64 Int64.zero)] ] =>
           rewrite Ptrofs.add_zero
         | [ |- context [Ptrofs.add Ptrofs.zero _] ] =>
           rewrite Ptrofs.add_zero_l
         | [ |- context [Ptrofs.repr (Ptrofs.unsigned _)] ] =>
           rewrite Ptrofs.repr_unsigned
         end.

Ltac solve_symb_inj :=
  match goal with
  | [  H1 : Globalenvs.Genv.symbol_address _ _ _ = _,
       H2 : Genv.symbol_address _ _ _ = _ |- _ ] =>
    exploit inject_symbol_sectlabel; eauto;
    rewrite H1, H2; auto
  end.

Ltac destr_pair_if :=
  repeat match goal with
         | [ |- context [match ?a with pair _ _ => _ end] ] =>
           destruct a eqn:?
         | [ |- context [if ?h then _ else _] ] =>
           destruct h eqn:?
         end.

Ltac inject_match :=
  match goal with
  | [ |- Val.inject ?j (match ?a with _ => _ end) (match ?b with _ => _ end) ] =>
    assert (Val.inject j a b)
  end.

Ltac inv_valinj :=
  match goal with
         | [ H : Val.inject _ (Vint _) _ |- _ ] =>
           inversion H; subst
         | [ H : Val.inject _ (Vlong _) _ |- _ ] =>
           inversion H; subst
         | [ H : Val.inject _ (Vptr _ _) _ |- _ ] =>
           inversion H; subst
         end.

Ltac destr_valinj_right H :=
  match type of H with
  | Val.inject _ _ ?a =>
    destruct a eqn:?
  end.

Ltac destr_valinj_left H :=
  match type of H with
  | Val.inject _ ?a ?b =>
    destruct a eqn:?
  end.

Lemma eval_addrmode32_inject: forall gm lm j a1 a2 rs1 rs2,
    match_sminj gm lm j ->
    regset_inject j rs1 rs2 ->
    transl_addr_mode gm a1 = OK a2 ->
    Val.inject j (Asm.eval_addrmode32 ge a1 rs1) (FlatAsm.eval_addrmode32 tge a2 rs2).
Proof.
  intros. unfold Asm.eval_addrmode32, FlatAsm.eval_addrmode32.
  destruct a1. destruct base, ofs, const; simpl in *; monadInvX H1; simpl; simpl_goal; auto.
  - apply Val.add_inject; auto. destr_pair_if; repeat apply Val.add_inject; auto.
    apply mul_inject; auto.
  - destr_pair_if;
      try (repeat apply Val.add_inject; auto);
      try (eapply inject_symbol_sectlabel; eauto).
    apply mul_inject; auto.
  - apply Val.add_inject; auto.
  - apply Val.add_inject; auto.
    destruct (Globalenvs.Genv.symbol_address ge i0 i1) eqn:SYMADDR; auto.
    simpl_goal.
    exploit inject_symbol_sectlabel; eauto.
    rewrite SYMADDR. intros. inv H1.
  - destr_pair_if.
    + inject_match.
      apply Val.add_inject; auto.
      destruct (Val.add (rs1 i) (Vint (Int.repr z))); auto.
      inv_valinj. simpl_goal. congruence.
    + inject_match. apply Val.add_inject; auto.
      destruct (Val.add (rs1 i) (Vint (Int.repr z))); auto;
      inv_valinj; simpl_goal; congruence.
    + inject_match. repeat apply Val.add_inject; auto.
      apply mul_inject; auto.
      destruct (Val.add (Val.mul (rs1 i) (Vint (Int.repr z0))) (Vint (Int.repr z))); auto;
      inv_valinj; simpl_goal; congruence.
    + inject_match. repeat apply Val.add_inject; auto.
      apply mul_inject; auto.
      destruct (Val.add (Val.mul (rs1 i) (Vint (Int.repr z0))) (Vint (Int.repr z))); auto;
      inv_valinj; simpl_goal; congruence.
  - destr_pair_if.
    + inject_match.
      apply Val.add_inject; auto.
      eapply inject_symbol_sectlabel; eauto.
      destruct (Val.add (rs1 i1) (Globalenvs.Genv.symbol_address ge i i0)); auto.
      inv_valinj. simpl_goal. congruence.
    + inject_match. apply Val.add_inject; auto.
      eapply inject_symbol_sectlabel; eauto.
      destruct (Val.add (rs1 i1) (Globalenvs.Genv.symbol_address ge i i0)); auto;
      inv_valinj; simpl_goal; congruence.
    + inject_match. repeat apply Val.add_inject; auto.
      apply mul_inject; auto.
      eapply inject_symbol_sectlabel; eauto.
      destruct (Val.add (Val.mul (rs1 i1) (Vint (Int.repr z))) (Globalenvs.Genv.symbol_address ge i i0)); auto;
      inv_valinj; simpl_goal; congruence.
    + inject_match. repeat apply Val.add_inject; auto.
      apply mul_inject; auto.
      eapply inject_symbol_sectlabel; eauto.
      destruct (Val.add (Val.mul (rs1 i1) (Vint (Int.repr z))) (Globalenvs.Genv.symbol_address ge i i0)); auto;
      inv_valinj; simpl_goal; congruence.
  - inject_match.
    +  destruct (Globalenvs.Genv.symbol_address ge i i0) eqn:EQ; auto.
       unfold Globalenvs.Genv.symbol_address in EQ. destruct (Genv.find_symbol ge i); inv EQ.
    + destr_valinj_left H1; auto. destruct Archi.ptr64; inv H1.
Qed.

Lemma eval_addrmode64_inject: forall gm lm j a1 a2 rs1 rs2,
    match_sminj gm lm j ->
    regset_inject j rs1 rs2 ->
    transl_addr_mode gm a1 = OK a2 ->
    Val.inject j (Asm.eval_addrmode64 ge a1 rs1) (FlatAsm.eval_addrmode64 tge a2 rs2).
Proof.
  intros. unfold Asm.eval_addrmode64, FlatAsm.eval_addrmode64.
  destruct a1, a2. destruct base, ofs, const; simpl in *; monadInvX H1; simpl; simpl_goal;
  try apply Val.add_inject; auto.
  - destr_pair_if.
    + repeat apply Val.addl_inject; auto.
    + repeat apply Val.addl_inject; auto.
      apply mull_inject; auto.
  - destr_pair_if.
    + repeat apply Val.addl_inject; auto.
      eapply inject_symbol_sectlabel; eauto.
    + repeat apply Val.addl_inject; auto.
      apply mull_inject; auto.
      eapply inject_symbol_sectlabel; eauto.
  - simpl_goal. apply Val.addl_inject; auto.
  - apply Val.addl_inject; auto.
    destruct (Globalenvs.Genv.symbol_address ge i0 i1) eqn:EQ; auto.
    unfold Globalenvs.Genv.symbol_address in EQ. destruct (Genv.find_symbol ge i0); inv EQ.
    destruct Archi.ptr64; auto. simpl_goal.
    exploit inject_symbol_sectlabel; eauto. rewrite EQ. unfold Genv.symbol_address, Genv.label_to_ptr.
    auto.
  - destr_pair_if.
    + inject_match.
      apply Val.addl_inject; auto.
      destruct (Val.addl (rs1 i) (Vlong (Int64.repr z))); simpl_goal; auto;
      inv_valinj; simpl_goal; congruence.
    + inject_match. apply Val.addl_inject; auto.
      destruct (Val.addl (rs1 i) (Vlong (Int64.repr z))); auto;
      inv_valinj; simpl_goal; congruence.
    + inject_match. repeat apply Val.addl_inject; auto.
      apply mull_inject; auto.
      destruct (Val.addl (Val.mull (rs1 i) (Vlong (Int64.repr z0))) (Vlong (Int64.repr z))); auto;
      inv_valinj; simpl_goal; congruence.
    + inject_match. repeat apply Val.addl_inject; auto.
      apply mull_inject; auto.
      destruct (Val.addl (Val.mull (rs1 i) (Vlong (Int64.repr z0))) (Vlong (Int64.repr z))); auto;
      inv_valinj; simpl_goal; congruence.
  - destr_pair_if.
    + inject_match.
      apply Val.addl_inject; auto.
      eapply inject_symbol_sectlabel; eauto.
      destruct (Val.addl (rs1 i1) (Globalenvs.Genv.symbol_address ge i i0)); auto;
      inv_valinj; simpl_goal; congruence.
    + inject_match. apply Val.addl_inject; auto.
      eapply inject_symbol_sectlabel; eauto.
      destruct (Val.addl (rs1 i1) (Globalenvs.Genv.symbol_address ge i i0)); auto;
      inv_valinj; simpl_goal; congruence.
    + inject_match. repeat apply Val.addl_inject; auto.
      apply mull_inject; auto.
      eapply inject_symbol_sectlabel; eauto.
      destruct (Val.addl (Val.mull (rs1 i1) (Vlong (Int64.repr z))) (Globalenvs.Genv.symbol_address ge i i0)); auto;
      inv_valinj; simpl_goal; congruence.
    + inject_match. repeat apply Val.addl_inject; auto.
      apply mull_inject; auto.
      eapply inject_symbol_sectlabel; eauto.
      destruct (Val.addl (Val.mull (rs1 i1) (Vlong (Int64.repr z))) (Globalenvs.Genv.symbol_address ge i i0)); auto;
      inv_valinj; simpl_goal; congruence.
  - inject_match.
    + destruct (Globalenvs.Genv.symbol_address ge i i0) eqn:EQ; auto.
      unfold Globalenvs.Genv.symbol_address in EQ. destruct (Genv.find_symbol ge i); inv EQ.
      destruct Archi.ptr64; auto. simpl_goal.
      exploit inject_symbol_sectlabel; eauto. rewrite EQ. unfold Genv.symbol_address, Genv.label_to_ptr.
      auto.
    + destr_valinj_left H1; auto; destruct Archi.ptr64; inv H1.
      simpl_goal. eapply Val.inject_ptr; eauto.
Qed.

Lemma eval_addrmode_inject: forall gm lm j a1 a2 rs1 rs2,
    match_sminj gm lm j ->
    regset_inject j rs1 rs2 ->
    transl_addr_mode gm a1 = OK a2 ->
    Val.inject j (Asm.eval_addrmode ge a1 rs1) (FlatAsm.eval_addrmode tge a2 rs2).
Proof.
  intros. unfold Asm.eval_addrmode, eval_addrmode. destruct Archi.ptr64.
  + eapply eval_addrmode64_inject; eauto.
  + eapply eval_addrmode32_inject; eauto.
Qed.

Lemma exec_load_step: forall j rs1 rs2 m1 m2 rs1' m1' gm lm sz chunk rd a1 a2
                          (MINJ: Mem.inject j (def_frame_inj m1) m1 m2)
                          (MATCHSMINJ: match_sminj gm lm j)
                          (* (GINJFLATMEM: globs_inj_into_flatmem j) *)
                          (INSTRINTERNAL: valid_instr_offset_is_internal j)
                          (EXTEXTERNAL: extfun_entry_is_external j)
                          (MATCHFINDFUNCT: match_find_funct j)
                          (RSINJ: regset_inject j rs1 rs2)
                          (GBVALID: glob_block_valid m1)
                          (GMUNDEF: gid_map_for_undef_syms gm),
    Asm.exec_load ge chunk m1 a1 rs1 rd sz = Next rs1' m1' ->
    transl_addr_mode gm a1 = OK a2 ->
    exists rs2' m2',
      FlatAsm.exec_load tge chunk m2 a2 rs2 rd sz = Next rs2' m2' /\
      match_states (State rs1' m1') (State rs2' m2').
Proof.
  intros. unfold Asm.exec_load in *.  
  exploit eval_addrmode_inject; eauto. intro EMODINJ. 
  destruct (Mem.loadv chunk m1 (Asm.eval_addrmode ge a1 rs1)) eqn:MLOAD; try congruence.
  exploit Mem.loadv_inject; eauto. intros (v2 & MLOADV & VINJ).
  eexists. eexists. split.
  - unfold exec_load. rewrite MLOADV. auto.
  - inv H. eapply match_states_intro; eauto.
    apply nextinstr_pres_inject. apply undef_regs_pres_inject.
    apply regset_inject_expand; eauto.
Qed.

Lemma store_pres_glob_block_valid : forall m1 chunk b v ofs m2,
  Mem.store chunk m1 b ofs v = Some m2 -> glob_block_valid m1 -> glob_block_valid m2.
Proof.
  unfold glob_block_valid in *. intros.
  eapply Mem.store_valid_block_1; eauto.
Qed.

Lemma storev_pres_glob_block_valid : forall m1 chunk ptr v m2,
  Mem.storev chunk m1 ptr v = Some m2 -> glob_block_valid m1 -> glob_block_valid m2.
Proof.
  unfold Mem.storev. intros. destruct ptr; try congruence.
  eapply store_pres_glob_block_valid; eauto.
Qed.

Lemma exec_store_step: forall j rs1 rs2 m1 m2 rs1' m1' gm lm sz chunk r a1 a2 dregs
                         (MINJ: Mem.inject j (def_frame_inj m1) m1 m2)
                         (MATCHSMINJ: match_sminj gm lm j)
                         (* (GINJFLATMEM: globs_inj_into_flatmem j) *)
                         (INSTRINTERNAL: valid_instr_offset_is_internal j)
                         (EXTEXTERNAL: extfun_entry_is_external j)
                         (MATCHFINDFUNCT: match_find_funct j)
                         (RSINJ: regset_inject j rs1 rs2)
                         (GBVALID: glob_block_valid m1)
                         (GMUNDEF: gid_map_for_undef_syms gm),
    Asm.exec_store ge chunk m1 a1 rs1 r dregs sz = Next rs1' m1' ->
    transl_addr_mode gm a1 = OK a2 ->
    exists rs2' m2',
      FlatAsm.exec_store tge chunk m2 a2 rs2 r dregs sz = Next rs2' m2' /\
      match_states (State rs1' m1') (State rs2' m2').
Proof.
  intros. unfold Asm.exec_store in *.  
  exploit eval_addrmode_inject; eauto. intro EMODINJ. 
  destruct (Mem.storev chunk m1 (Asm.eval_addrmode ge a1 rs1) (rs1 r)) eqn:MSTORE; try congruence.
  exploit Mem.storev_mapped_inject; eauto. intros (m2' & MSTOREV & MINJ').
  eexists. eexists. split.
  - unfold exec_store. rewrite MSTOREV. auto.
  - inv H. eapply match_states_intro; eauto.
    erewrite <- storev_pres_def_frame_inj; eauto.
    apply nextinstr_pres_inject. repeat apply undef_regs_pres_inject. auto.
    eapply storev_pres_glob_block_valid; eauto.
Qed.

Inductive opt_val_inject (j:meminj) : option val -> option val -> Prop :=
| opt_val_inject_none v : opt_val_inject j None v
| opt_val_inject_some v1 v2 : Val.inject j v1 v2 -> 
                                opt_val_inject j (Some v1) (Some v2).

Lemma maketotal_inject : forall v1 v2 j,
    opt_val_inject j v1 v2 -> Val.inject j (Val.maketotal v1) (Val.maketotal v2).
Proof.
  intros. inversion H; simpl; subst; auto.
Qed.

Inductive opt_lessdef {A:Type} : option A -> option A -> Prop :=
| opt_lessdef_none v : opt_lessdef None v
| opt_lessdef_some v : opt_lessdef (Some v) (Some v). 

Lemma vzero_inject : forall j,
  Val.inject j Vzero Vzero.
Proof.
  intros. unfold Vzero. auto.
Qed.

Lemma vtrue_inject : forall j,
  Val.inject j Vtrue Vtrue.
Proof.
  intros. unfold Vtrue. auto.
Qed.

Lemma vfalse_inject : forall j,
  Val.inject j Vfalse Vfalse.
Proof.
  intros. unfold Vfalse. auto.
Qed.

Lemma vofbool_inject : forall j v,
  Val.inject j (Val.of_bool v) (Val.of_bool v).
Proof.
  destruct v; simpl.
  - apply vtrue_inject.
  - apply vfalse_inject.
Qed.
  
Lemma neg_inject : forall v1 v2 j,
    Val.inject j v1 v2 -> Val.inject j (Val.neg v1) (Val.neg v2).
Proof.
  intros. unfold Val.neg. 
  destruct v1; auto. inv H. auto.
Qed.

Lemma negl_inject : forall v1 v2 j,
    Val.inject j v1 v2 -> Val.inject j (Val.negl v1) (Val.negl v2).
Proof.
  intros. unfold Val.negl. 
  destruct v1; auto. inv H. auto.
Qed.

Lemma mullhs_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> Val.inject j (Val.mullhs v1 v1') (Val.mullhs v2 v2').
Proof.
  intros. unfold Val.mullhs. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. auto.
Qed.

Lemma mullhu_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> Val.inject j (Val.mullhu v1 v1') (Val.mullhu v2 v2').
Proof.
  intros. unfold Val.mullhu. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. auto.
Qed.

Lemma mulhu_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> Val.inject j (Val.mulhu v1 v1') (Val.mulhu v2 v2').
Proof.
  intros. unfold Val.mulhu. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. auto.
Qed.


Lemma shr_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> Val.inject j (Val.shr v1 v1') (Val.shr v2 v2').
Proof.
  intros. unfold Val.shr. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. 
  destruct (Int.ltu i0 Int.iwordsize); auto.
Qed.

Lemma shrl_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> Val.inject j (Val.shrl v1 v1') (Val.shrl v2 v2').
Proof.
  intros. unfold Val.shrl. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. 
  destruct (Int.ltu i0 Int64.iwordsize'); auto.
Qed.

Lemma shru_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> Val.inject j (Val.shru v1 v1') (Val.shru v2 v2').
Proof.
  intros. unfold Val.shru. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. 
  destruct (Int.ltu i0 Int.iwordsize); auto.
Qed.

Lemma shrlu_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> Val.inject j (Val.shrlu v1 v1') (Val.shrlu v2 v2').
Proof.
  intros. unfold Val.shrlu. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. 
  destruct (Int.ltu i0 Int64.iwordsize'); auto.
Qed.

Lemma or_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> Val.inject j (Val.or v1 v1') (Val.or v2 v2').
Proof.
  intros. unfold Val.or. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. auto.
Qed.

Lemma orl_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> Val.inject j (Val.orl v1 v1') (Val.orl v2 v2').
Proof.
  intros. unfold Val.orl. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. auto.
Qed.

Lemma ror_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> Val.inject j (Val.ror v1 v1') (Val.ror v2 v2').
Proof.
  intros. unfold Val.ror. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. auto.
Qed.

Lemma rorl_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> Val.inject j (Val.rorl v1 v1') (Val.rorl v2 v2').
Proof.
  intros. unfold Val.rorl. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. auto.
Qed.


Lemma xor_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> Val.inject j (Val.xor v1 v1') (Val.xor v2 v2').
Proof.
  intros. unfold Val.xor. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. auto.
Qed.

Lemma xorl_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> Val.inject j (Val.xorl v1 v1') (Val.xorl v2 v2').
Proof.
  intros. unfold Val.xorl. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. auto.
Qed.

Lemma and_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> Val.inject j (Val.and v1 v1') (Val.and v2 v2').
Proof.
  intros. unfold Val.and. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. auto.
Qed.

Lemma andl_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> Val.inject j (Val.andl v1 v1') (Val.andl v2 v2').
Proof.
  intros. unfold Val.andl. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. auto.
Qed.

Lemma notl_inject : forall v1 v2 j,
    Val.inject j v1 v2 -> Val.inject j (Val.notl v1) (Val.notl v2).
Proof.
  intros. unfold Val.notl. 
  destruct v1; auto. inv H. auto.
Qed.

Lemma notint_inject : forall v1 v2 j,
    Val.inject j v1 v2 -> Val.inject j (Val.notint v1) (Val.notint v2).
Proof.
  intros. unfold Val.notint. 
  destruct v1; auto. inv H. auto.
Qed.

Lemma shl_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> Val.inject j (Val.shl v1 v1') (Val.shl v2 v2').
Proof.
  intros. unfold Val.shl. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. 
  destruct (Int.ltu i0 Int.iwordsize); auto.
Qed.

Lemma shll_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> Val.inject j (Val.shll v1 v1') (Val.shll v2 v2').
Proof.
  intros. unfold Val.shll. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. 
  destruct (Int.ltu i0 Int64.iwordsize'); auto.
Qed.

Lemma addf_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> Val.inject j (Val.addf v1 v1') (Val.addf v2 v2').
Proof.
  intros. unfold Val.addf. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. auto.
Qed.

Lemma subf_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> Val.inject j (Val.subf v1 v1') (Val.subf v2 v2').
Proof.
  intros. unfold Val.subf. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. auto.
Qed.

Lemma mulf_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> Val.inject j (Val.mulf v1 v1') (Val.mulf v2 v2').
Proof.
  intros. unfold Val.mulf. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. auto.
Qed.

Lemma divf_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> Val.inject j (Val.divf v1 v1') (Val.divf v2 v2').
Proof.
  intros. unfold Val.divf. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. auto.
Qed.

Lemma negf_inject : forall v1 v2 j,
    Val.inject j v1 v2 -> Val.inject j (Val.negf v1) (Val.negf v2).
Proof.
  intros. unfold Val.negf. 
  destruct v1; auto. inv H. auto.
Qed.

Lemma absf_inject : forall v1 v2 j,
    Val.inject j v1 v2 -> Val.inject j (Val.absf v1) (Val.absf v2).
Proof.
  intros. unfold Val.absf. 
  destruct v1; auto. inv H. auto.
Qed.

Lemma addfs_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> Val.inject j (Val.addfs v1 v1') (Val.addfs v2 v2').
Proof.
  intros. unfold Val.addfs. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. auto.
Qed.

Lemma subfs_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> Val.inject j (Val.subfs v1 v1') (Val.subfs v2 v2').
Proof.
  intros. unfold Val.subfs. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. auto.
Qed.

Lemma mulfs_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> Val.inject j (Val.mulfs v1 v1') (Val.mulfs v2 v2').
Proof.
  intros. unfold Val.mulfs. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. auto.
Qed.

Lemma divfs_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> Val.inject j (Val.divfs v1 v1') (Val.divfs v2 v2').
Proof.
  intros. unfold Val.divfs. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. auto.
Qed.

Lemma negfs_inject : forall v1 v2 j,
    Val.inject j v1 v2 -> Val.inject j (Val.negfs v1) (Val.negfs v2).
Proof.
  intros. unfold Val.negfs. 
  destruct v1; auto. inv H. auto.
Qed.

Lemma absfs_inject : forall v1 v2 j,
    Val.inject j v1 v2 -> Val.inject j (Val.absfs v1) (Val.absfs v2).
Proof.
  intros. unfold Val.absfs. 
  destruct v1; auto. inv H. auto.
Qed.

(* Injection for cmpu_bool and cmplu_bool *)
Lemma valid_ptr_inj : forall j m m',
    Mem.inject j (def_frame_inj m) m m' ->
    forall b i b' delta,                                  
      j b = Some (b', delta) ->
      Mem.valid_pointer m b (Ptrofs.unsigned i) = true ->
      Mem.valid_pointer m' b' (Ptrofs.unsigned (Ptrofs.add i (Ptrofs.repr delta))) = true.
Proof.
  intros. eapply Mem.valid_pointer_inject'; eauto.
Qed.


Lemma weak_valid_ptr_inj: forall j m m',
  Mem.inject j (def_frame_inj m) m m' ->
  forall b1 ofs b2 delta,
  j b1 = Some(b2, delta) ->
  Mem.weak_valid_pointer m b1 (Ptrofs.unsigned ofs) = true ->
  Mem.weak_valid_pointer m' b2 (Ptrofs.unsigned (Ptrofs.add ofs (Ptrofs.repr delta))) = true.
Proof.
  intros. eapply Mem.weak_valid_pointer_inject'; eauto.
Qed.

Lemma weak_valid_ptr_no_overflow: forall j m m',
  Mem.inject j (def_frame_inj m) m m' ->
  forall b1 ofs b2 delta,
  j b1 = Some(b2, delta) ->
  Mem.weak_valid_pointer m b1 (Ptrofs.unsigned ofs) = true ->
  0 <= Ptrofs.unsigned ofs + Ptrofs.unsigned (Ptrofs.repr delta) <= Ptrofs.max_unsigned.
Proof.
  intros. eapply Mem.weak_valid_pointer_inject_no_overflow; eauto.
Qed.

Lemma valid_different_ptrs_inj: forall j m m',
  Mem.inject j (def_frame_inj m) m m' ->
  forall b1 ofs1 b2 ofs2 b1' delta1 b2' delta2,
  b1 <> b2 ->
  Mem.valid_pointer m b1 (Ptrofs.unsigned ofs1) = true ->
  Mem.valid_pointer m b2 (Ptrofs.unsigned ofs2) = true ->
  j b1 = Some (b1', delta1) ->
  j b2 = Some (b2', delta2) ->
  b1' <> b2' \/
  Ptrofs.unsigned (Ptrofs.add ofs1 (Ptrofs.repr delta1)) <> Ptrofs.unsigned (Ptrofs.add ofs2 (Ptrofs.repr delta2)).
Proof.
  intros. eapply Mem.different_pointers_inject; eauto.
Qed.

Definition cmpu_bool_inject := fun j m m' (MINJ: Mem.inject j (def_frame_inj m) m m') =>
                     Val.cmpu_bool_inject j (Mem.valid_pointer m) (Mem.valid_pointer m')
                                          (valid_ptr_inj j m m' MINJ)
                                          (weak_valid_ptr_inj j m m' MINJ)
                                          (weak_valid_ptr_no_overflow j m m' MINJ)
                                          (valid_different_ptrs_inj j m m' MINJ).

Lemma cmpu_bool_lessdef : forall j v1 v2 v1' v2' m m' c,
    Val.inject j v1 v1' -> Val.inject j v2 v2' ->
    Mem.inject j (def_frame_inj m) m m' ->
    opt_lessdef (Val.cmpu_bool (Mem.valid_pointer m) c v1 v2)
                (Val.cmpu_bool (Mem.valid_pointer m') c v1' v2').
Proof.
  intros. destruct (Val.cmpu_bool (Mem.valid_pointer m) c v1 v2) eqn:EQ.
  - exploit (cmpu_bool_inject j m m' H1 c v1 v2); eauto.
    intros. rewrite H2. constructor.
  - constructor.
Qed.

Definition cmplu_bool_inject := fun j m m' (MINJ: Mem.inject j (def_frame_inj m) m m') =>
                     Val.cmplu_bool_inject j (Mem.valid_pointer m) (Mem.valid_pointer m')
                                           (valid_ptr_inj j m m' MINJ)
                                           (weak_valid_ptr_inj j m m' MINJ)
                                           (weak_valid_ptr_no_overflow j m m' MINJ)
                                           (valid_different_ptrs_inj j m m' MINJ).


Lemma cmplu_bool_lessdef : forall j v1 v2 v1' v2' m m' c,
    Val.inject j v1 v1' -> Val.inject j v2 v2' ->
    Mem.inject j (def_frame_inj m) m m' ->
    opt_lessdef (Val.cmplu_bool (Mem.valid_pointer m) c v1 v2)
                (Val.cmplu_bool (Mem.valid_pointer m') c v1' v2').
Proof.
  intros. destruct (Val.cmplu_bool (Mem.valid_pointer m) c v1 v2) eqn:EQ.
  - exploit (cmplu_bool_inject j m m' H1 c v1 v2); eauto.
    intros. rewrite H2. constructor.
  - constructor.
Qed.

Lemma val_of_optbool_lessdef : forall j v1 v2,
    opt_lessdef v1 v2 -> Val.inject j (Val.of_optbool v1) (Val.of_optbool v2).
Proof.
  intros. destruct v1; auto.
  simpl. inv H. destruct b; constructor.
Qed.

Lemma cmpu_inject : forall j v1 v2 v1' v2' m m' c,
    Val.inject j v1 v1' -> Val.inject j v2 v2' ->
    Mem.inject j (def_frame_inj m) m m' ->
    Val.inject j (Val.cmpu (Mem.valid_pointer m) c v1 v2)
               (Val.cmpu (Mem.valid_pointer m') c v1' v2').
Proof.
  intros. unfold Val.cmpu.
  exploit (cmpu_bool_lessdef j v1 v2); eauto. intros. 
  exploit val_of_optbool_lessdef; eauto.
Qed.

Lemma val_negative_inject: forall j v1 v2,
  Val.inject j v1 v2 -> Val.inject j (Val.negative v1) (Val.negative v2).
Proof.
  intros. unfold Val.negative. destruct v1; auto.
  inv H. auto.
Qed.

Lemma val_negativel_inject: forall j v1 v2,
  Val.inject j v1 v2 -> Val.inject j (Val.negativel v1) (Val.negativel v2).
Proof.
  intros. unfold Val.negativel. destruct v1; auto.
  inv H. auto.
Qed.

Lemma sub_overflow_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> 
    Val.inject j (Val.sub_overflow v1 v1') (Val.sub_overflow v2 v2').
Proof.
  intros. unfold Val.sub_overflow. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. auto.
Qed.

Lemma subl_overflow_inject : forall v1 v2 v1' v2' j,
    Val.inject j v1 v2 -> Val.inject j v1' v2' -> 
    Val.inject j (Val.subl_overflow v1 v1') (Val.subl_overflow v2 v2').
Proof.
  intros. unfold Val.subl_overflow. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. auto.
Qed.

Lemma compare_ints_inject: forall j v1 v2 v1' v2' rs rs' m m',
    Val.inject j v1 v1' -> Val.inject j v2 v2' ->
    Mem.inject j (def_frame_inj m) m m' ->
    regset_inject j rs rs' -> 
    regset_inject j (compare_ints v1 v2 rs m) (compare_ints v1' v2' rs' m').
Proof.
  intros. unfold compare_ints, Asm.compare_ints.
  repeat apply regset_inject_expand; auto.
  - apply cmpu_inject; auto.
  - apply cmpu_inject; auto.
  - apply val_negative_inject. apply Val.sub_inject; auto.
  - apply sub_overflow_inject; auto.
Qed.

Lemma cmplu_lessdef : forall j v1 v2 v1' v2' m m' c,
    Val.inject j v1 v1' -> Val.inject j v2 v2' ->
    Mem.inject j (def_frame_inj m) m m' ->
    opt_val_inject j (Val.cmplu (Mem.valid_pointer m) c v1 v2)
                     (Val.cmplu (Mem.valid_pointer m') c v1' v2').
Proof.
  intros. unfold Val.cmplu.
  exploit (cmplu_bool_lessdef j v1 v2 v1' v2' m m' c); eauto. intros.
  inversion H2; subst; simpl; constructor.
  apply vofbool_inject.
Qed.

Lemma compare_longs_inject: forall j v1 v2 v1' v2' rs rs' m m',
    Val.inject j v1 v1' -> Val.inject j v2 v2' ->
    Mem.inject j (def_frame_inj m) m m' ->
    regset_inject j rs rs' -> 
    regset_inject j (compare_longs v1 v2 rs m) (compare_longs v1' v2' rs' m').
Proof.
  intros. unfold compare_longs, Asm.compare_longs.
  repeat apply regset_inject_expand; auto.
  - unfold Val.cmplu.
    exploit (cmplu_bool_lessdef j v1 v2 v1' v2' m m' Ceq); eauto. intros.
    inversion H3; subst.
    + simpl. auto. 
    + simpl. apply vofbool_inject.
  - unfold Val.cmplu.
    exploit (cmplu_bool_lessdef j v1 v2 v1' v2' m m' Clt); eauto. intros.
    inversion H3; subst.
    + simpl. auto. 
    + simpl. apply vofbool_inject.
  - apply val_negativel_inject. apply Val.subl_inject; auto.
  - apply subl_overflow_inject; auto.
Qed.

Ltac solve_val_inject :=
  match goal with
  (* | [ H : Val.inject _ (Vint _) (Vlong _) |- _] => inversion H *)
  (* | [ H : Val.inject _ (Vint _) (Vfloat _) |- _] => inversion H *)
  (* | [ H : Val.inject _ (Vint _) (Vsingle _) |- _] => inversion H *)
  (* | [ H : Val.inject _ (Vint _) (Vptr _ _) |- _] => inversion H *)
  (* | [ H : Val.inject _ (Vptr _ _) (Vlong _) |- _] => inversion H *)
  (* | [ H : Val.inject _ (Vptr _ _) (Vfloat _) |- _] => inversion H *)
  (* | [ H : Val.inject _ (Vptr _ _) (Vsingle _) |- _] => inversion H *)
  | [ H : Val.inject _ (Vfloat _) Vundef |- _] => inversion H
  | [ H : Val.inject _ (Vfloat _) (Vint _) |- _] => inversion H
  | [ H : Val.inject _ (Vfloat _) (Vlong _) |- _] => inversion H
  | [ H : Val.inject _ (Vfloat _) (Vsingle _) |- _] => inversion H
  | [ H : Val.inject _ (Vfloat _) (Vptr _ _) |- _] => inversion H
  | [ H : Val.inject _ (Vfloat _) (Vfloat _) |- _] => inv H; solve_val_inject
  | [ H : Val.inject _ (Vsingle _) Vundef |- _] => inversion H
  | [ H : Val.inject _ (Vsingle _) (Vint _) |- _] => inversion H
  | [ H : Val.inject _ (Vsingle _) (Vlong _) |- _] => inversion H
  | [ H : Val.inject _ (Vsingle _) (Vsingle _) |- _] => inv H; solve_val_inject
  | [ H : Val.inject _ (Vsingle _) (Vptr _ _) |- _] => inversion H
  | [ H : Val.inject _ (Vsingle _) (Vfloat _) |- _] => inversion H
  | [ |- Val.inject _ (Val.of_bool ?v) (Val.of_bool ?v) ] => apply vofbool_inject
  | [ |- Val.inject _ Vundef _ ] => auto
  end.

Ltac solve_regset_inject :=
  match goal with
  | [ H: regset_inject ?j ?rs1 ?rs2 |- regset_inject ?j (Asm.undef_regs ?uregs ?rs1) (Asm.undef_regs ?uregs ?rs2)] =>
    apply undef_regs_pres_inject; auto
  | [ |- regset_inject _ (Asm.undef_regs _ _) _ ] =>
    unfold Asm.undef_regs; solve_regset_inject
  | [ |- regset_inject _ _ (Asm.undef_regs _ _) ] =>
    unfold Asm.undef_regs; simpl; solve_regset_inject
  | [ |- regset_inject _ (?rs1 # ?r <- ?v1) (?rs2 # ?r <- ?v2) ] =>
    apply regset_inject_expand; [solve_regset_inject | solve_val_inject]
  | [ H: regset_inject ?j ?rs1 ?rs2 |- regset_inject ?j ?rs1 ?rs2 ] =>
    auto
  end.

Lemma compare_floats_inject: forall j v1 v2 v1' v2' rs rs',
    Val.inject j v1 v1' -> Val.inject j v2 v2' ->
    regset_inject j rs rs' -> 
    regset_inject j (compare_floats v1 v2 rs) (compare_floats v1' v2' rs').
Proof.
  intros. unfold compare_floats, Asm.compare_floats.
  destruct v1, v2, v1', v2'; try solve_regset_inject. 
Qed.

Lemma compare_floats32_inject: forall j v1 v2 v1' v2' rs rs',
    Val.inject j v1 v1' -> Val.inject j v2 v2' ->
    regset_inject j rs rs' -> 
    regset_inject j (compare_floats32 v1 v2 rs) (compare_floats32 v1' v2' rs').
Proof.
  intros. unfold compare_floats32, Asm.compare_floats32.
  destruct v1, v2, v1', v2'; try solve_regset_inject. 
Qed.

Lemma zero_ext_inject : forall v1 v2 n j,
    Val.inject j v1 v2 -> Val.inject j (Val.zero_ext n v1) (Val.zero_ext n v2).
Proof.
  intros. unfold Val.zero_ext. 
  destruct v1; auto. inv H. auto.
Qed.

Lemma sign_ext_inject : forall v1 v2 n j,
    Val.inject j v1 v2 -> Val.inject j (Val.sign_ext n v1) (Val.sign_ext n v2).
Proof.
  intros. unfold Val.sign_ext. 
  destruct v1; auto. inv H. auto.
Qed.

Lemma longofintu_inject : forall v1 v2 j,
    Val.inject j v1 v2 -> Val.inject j (Val.longofintu v1) (Val.longofintu v2).
Proof.
  intros. unfold Val.longofintu. 
  destruct v1; auto. inv H. auto.
Qed.

Lemma longofint_inject : forall v1 v2 j,
    Val.inject j v1 v2 -> Val.inject j (Val.longofint v1) (Val.longofint v2).
Proof.
  intros. unfold Val.longofint. 
  destruct v1; auto. inv H. auto.
Qed.

Lemma singleoffloat_inject : forall v1 v2 j,
    Val.inject j v1 v2 -> Val.inject j (Val.singleoffloat v1) (Val.singleoffloat v2).
Proof.
  intros. unfold Val.singleoffloat. 
  destruct v1; auto. inv H. auto.
Qed.

Lemma loword_inject : forall v1 v2 j,
    Val.inject j v1 v2 -> Val.inject j (Val.loword v1) (Val.loword v2).
Proof.
  intros. unfold Val.loword. 
  destruct v1; auto. inv H. auto.
Qed.

Lemma floatofsingle_inject : forall v1 v2 j,
    Val.inject j v1 v2 -> Val.inject j (Val.floatofsingle v1) (Val.floatofsingle v2).
Proof.
  intros. unfold Val.floatofsingle. 
  destruct v1; auto. inv H. auto.
Qed.

Lemma intoffloat_inject : forall j v1 v2,
  Val.inject j v1 v2 -> opt_val_inject j (Val.intoffloat v1) (Val.intoffloat v2).
Proof.
  intros. unfold Val.intoffloat. destruct v1; try constructor.
  inv H. destruct (Floats.Float.to_int f); simpl. 
  - constructor. auto.
  - constructor.
Qed.

Lemma floatofint_inject : forall j v1 v2,
  Val.inject j v1 v2 -> opt_val_inject j (Val.floatofint v1) (Val.floatofint v2).
Proof.
  intros. unfold Val.floatofint. destruct v1; try constructor.
  inv H. constructor; auto.
Qed.

Lemma intofsingle_inject : forall j v1 v2,
  Val.inject j v1 v2 -> opt_val_inject j (Val.intofsingle v1) (Val.intofsingle v2).
Proof.
  intros. unfold Val.intofsingle. destruct v1; try constructor.
  inv H. destruct (Floats.Float32.to_int f); simpl; constructor; auto.
Qed.

Lemma longoffloat_inject : forall j v1 v2,
  Val.inject j v1 v2 -> opt_val_inject j (Val.longoffloat v1) (Val.longoffloat v2).
Proof.
  intros. unfold Val.longoffloat. destruct v1; try constructor.
  inv H. destruct (Floats.Float.to_long f) eqn:EQ; simpl; constructor; auto.
Qed.

Lemma floatoflong_inject : forall j v1 v2,
  Val.inject j v1 v2 -> opt_val_inject j (Val.floatoflong v1) (Val.floatoflong v2).
Proof.
  intros. unfold Val.floatoflong. destruct v1; try constructor.
  inv H. constructor; auto. 
Qed.

Lemma longofsingle_inject : forall j v1 v2,
  Val.inject j v1 v2 -> opt_val_inject j (Val.longofsingle v1) (Val.longofsingle v2).
Proof.
  intros. unfold Val.longofsingle. destruct v1; try constructor.
  inv H. destruct (Floats.Float32.to_long f) eqn:EQ; simpl; constructor; auto.
Qed.

Lemma singleoflong_inject : forall j v1 v2,
  Val.inject j v1 v2 -> opt_val_inject j (Val.singleoflong v1) (Val.singleoflong v2).
Proof.
  intros. unfold Val.singleoflong. destruct v1; try constructor.
  inv H. constructor; auto.
Qed.

Lemma singleofint_inject : forall j v1 v2,
  Val.inject j v1 v2 -> opt_val_inject j (Val.singleofint v1) (Val.singleofint v2).
Proof.
  intros. unfold Val.singleofint. destruct v1; try constructor.
  inv H. constructor; auto.
Qed.
  
Ltac solve_store_load :=
  match goal with
  | [ H : Asm.exec_instr _ _ _ _ _ _ = Next _ _ |- _ ] =>
    unfold Asm.exec_instr in H; simpl in H; solve_store_load
  | [ H : Asm.exec_store _ _ _ _ _ _ _ _ = Next _ _ |- _ ] =>
    exploit exec_store_step; eauto
  | [ H : Asm.exec_load _ _ _ _ _ _ _ = Next _ _ |- _ ] =>
    exploit exec_load_step; eauto
  end.

Ltac solve_opt_lessdef := 
  match goal with
  | [ |- opt_lessdef (match ?rs1 ?r with
                     | _ => _
                     end) _ ] =>
    let EQ := fresh "EQ" in (destruct (rs1 r) eqn:EQ; solve_opt_lessdef)
  | [ |- opt_lessdef None _ ] => constructor
  | [ |- opt_lessdef (Some _) (match ?rs2 ?r with
                              | _ => _
                              end) ] =>
    let EQ := fresh "EQ" in (destruct (rs2 r) eqn:EQ; solve_opt_lessdef)
  | [ H1: regset_inject _ ?rs1 ?rs2, H2: ?rs1 ?r = _, H3: ?rs2 ?r = _ |- _ ] =>
    generalize (H1 r); rewrite H2, H3; clear H2 H3; inversion 1; subst; solve_opt_lessdef
  | [ |- opt_lessdef (Some ?v) (Some ?v) ] => constructor
  end.

Lemma eval_testcond_inject: forall j c rs1 rs2,
    regset_inject j rs1 rs2 ->
    opt_lessdef (Asm.eval_testcond c rs1) (Asm.eval_testcond c rs2).
Proof.
  intros. destruct c; simpl; try solve_opt_lessdef.
Qed.

Hint Resolve nextinstr_nf_pres_inject nextinstr_pres_inject regset_inject_expand 
  regset_inject_expand_vundef_left undef_regs_pres_inject 
  zero_ext_inject sign_ext_inject longofintu_inject longofint_inject
  singleoffloat_inject loword_inject floatofsingle_inject intoffloat_inject maketotal_inject
  intoffloat_inject floatofint_inject intofsingle_inject singleofint_inject
  longoffloat_inject floatoflong_inject longofsingle_inject singleoflong_inject
  eval_addrmode32_inject eval_addrmode64_inject eval_addrmode_inject
  neg_inject negl_inject Val.add_inject Val.addl_inject
  Val.sub_inject Val.subl_inject mul_inject mull_inject mulhs_inject mulhu_inject
  mullhs_inject mullhu_inject shr_inject shrl_inject or_inject orl_inject
  xor_inject xorl_inject and_inject andl_inject notl_inject
  shl_inject shll_inject vzero_inject notint_inject
  shru_inject shrlu_inject ror_inject rorl_inject
  compare_ints_inject compare_longs_inject compare_floats_inject compare_floats32_inject
  addf_inject subf_inject mulf_inject divf_inject negf_inject absf_inject
  addfs_inject subfs_inject mulfs_inject divfs_inject negfs_inject absfs_inject
  val_of_optbool_lessdef eval_testcond_inject Val.offset_ptr_inject: inject_db.

Ltac solve_exec_instr :=
  match goal with
  | [ |- Next _ _ = Next _ _ ] =>
    reflexivity
  | [ |- context [eval_testcond _ _] ]=>
    unfold eval_testcond; solve_exec_instr
  | [ H: Asm.eval_testcond ?c ?r = _ |- context [Asm.eval_testcond ?c ?r] ] =>
    rewrite H; solve_exec_instr
  | [ H: _ = Asm.eval_testcond ?c ?r |- context [Asm.eval_testcond ?c ?r] ] =>
    rewrite <- H; solve_exec_instr
  end.

Ltac solve_match_states :=
  match goal with
  | [ H: Asm.Stuck = Next _ _ |- _ ] => inv H
  | [ |- exists _, _ ] => eexists; solve_match_states
  | [ |- (FlatAsm.exec_instr _ _ _ _ = Next _ _) /\ match_states _ _ ] =>
    split; [simpl; solve_exec_instr | econstructor; eauto; solve_match_states]
  | [ |- regset_inject _ _ _ ] =>
    eauto 10 with inject_db
  end.

Ltac destr_eval_testcond :=
  match goal with
  | [ H : match Asm.eval_testcond ?c ?rs with | _ => _ end = Next _ _ |- _ ] =>
    let ETEQ := fresh "ETEQ" in (
      destruct (Asm.eval_testcond c rs) eqn:ETEQ); destr_eval_testcond
  | [ H : Some ?b = Asm.eval_testcond _ _ |- _ ] =>
    match b with
    | true => fail 1
    | false => fail 1
    | _ => destruct b; destr_eval_testcond
    end
  | [ H : Asm.eval_testcond _ _ = Some ?b |- _] =>
    match b with
    | true => fail 1
    | false => fail 1
    | _ => destruct b; destr_eval_testcond
    end
  | [ H : Asm.Next _ _ = Next _ _ |- _ ] =>
    inv H; destr_eval_testcond
  | [ H: opt_lessdef (Some true) (Asm.eval_testcond _ _) |- _ ] =>
    inv H; destr_eval_testcond
  | [ H: opt_lessdef (Some false) (Asm.eval_testcond _ _) |- _ ] =>
    inv H; destr_eval_testcond
  | _ => idtac
  end.

Ltac destr_match_outcome :=
  match goal with
  | [ H: Asm.Stuck = Next _ _ |- _ ] => inv H
  | [ H: Asm.Next _ _ = Next _ _ |- _ ] => inv H; destr_match_outcome
  | [ H: match ?a with _ => _ end = Next _ _ |- _] =>
    let EQ := fresh "EQ" in (destruct a eqn:EQ; destr_match_outcome)
  | _ => idtac
  end.


Lemma goto_label_pres_mem : forall f l rs1 m1 rs1' m1',
    Asm.goto_label ge f l rs1 m1 = Next rs1' m1' -> m1 = m1'.
Proof.
  unfold Asm.goto_label. intros.
  destruct (label_pos l 0 (Asm.fn_code f)); try inv H. 
  destruct (rs1 Asm.PC); try inv H1.
  destruct (Genv.find_funct_ptr ge b); try inv H0. auto.
Qed.

Lemma goto_label_inject : forall rs1 rs2 gm lm id b f l l' j m1 m2 rs1' m1' ofs
                            (MATCHSMINJ: match_sminj gm lm j)
                            (RINJ: regset_inject j rs1 rs2)
                            (MINJ:Mem.inject j (def_frame_inj m1) m1 m2),
    rs1 PC = Vptr b ofs ->
    Genv.find_symbol ge id = Some b ->
    Genv.find_funct_ptr ge b = Some (Internal f) ->
    Asm.goto_label ge f l rs1 m1 = Next rs1' m1' ->
    lm id l = Some l' ->
    exists rs2', goto_label tge l' rs2 m2 = Next rs2' m2 /\
            regset_inject j rs1' rs2' /\ Mem.inject j (def_frame_inj m1') m1' m2.
Proof.
  intros. unfold Asm.goto_label in H2.
  destruct (label_pos l 0 (Asm.fn_code f)) eqn:EQLBL; try inv H2.
  setoid_rewrite H in H5. rewrite H1 in H5. inv H5.
  exploit agree_sminj_lbl; eauto. intros. 
  eexists. split.
  unfold goto_label. auto. split; auto.
  repeat apply regset_inject_expand; auto. 
Qed.

Lemma goto_tbl_label_inject : forall gm lm id tbl tbl' l b f j rs1 rs2 m1 m2 rs1' m1' i ofs
                                (MATCHSMINJ: match_sminj gm lm j)
                                (RINJ: regset_inject j rs1 rs2)
                                (MINJ:Mem.inject j (def_frame_inj m1) m1 m2),
    rs1 PC = Vptr b ofs ->
    Genv.find_symbol ge id = Some b ->
    Genv.find_funct_ptr ge b = Some (Internal f) ->
    list_nth_z tbl i = Some l ->
    Asm.goto_label ge f l ((rs1 # RAX <- Vundef) # RDX <- Vundef) m1 = Next rs1' m1' ->
    transl_tbl lm id tbl = OK tbl' ->
    exists rs2' l', 
      list_nth_z tbl' i = Some l' /\
      FlatAsm.goto_label tge l' ((rs2 # RAX <- Vundef) # RDX <- Vundef) m2 = Next rs2' m2 /\
      regset_inject j rs1' rs2' /\ Mem.inject j (def_frame_inj m1') m1' m2.
Proof.
  induction tbl; simpl; intros.
  - congruence.
  - destruct (zeq i 0).
    + inv H2. monadInvX H4.
      exploit (goto_label_inject ((rs1 # RAX <- Vundef) # RDX <- Vundef) ((rs2 # RAX <- Vundef) # RDX <- Vundef)); eauto with inject_db. 
      intros (rs2' & GLBL & RSINJ' & MINJ').
      eexists; eexists. split. simpl. auto. split.
      rewrite GLBL. auto. split; eauto.
    + monadInvX H4.
      exploit (IHtbl x); eauto.
      intros (rs2' & l' & LNTH & GLBL & RSINJ' & MINJ').
      exists rs2', l'. split. simpl. erewrite zeq_false; auto. split; auto.
Qed.


(** The internal step preserves the invariant *)
Lemma exec_instr_step : forall j rs1 rs2 m1 m2 rs1' m1' gm lm i i' id sid ofs ofs' f b
                        (MINJ: Mem.inject j (def_frame_inj m1) m1 m2)
                        (MATCHSMINJ: match_sminj gm lm j)
                        (* (GINJFLATMEM: globs_inj_into_flatmem j) *)
                        (INSTRINTERNAL: valid_instr_offset_is_internal j)
                        (EXTEXTERNAL: extfun_entry_is_external j)
                        (MATCHFINDFUNCT: match_find_funct j)
                        (RSINJ: regset_inject j rs1 rs2)
                        (GBVALID: glob_block_valid m1)
                        (GMUNDEF: gid_map_for_undef_syms gm),
    rs1 PC = Vptr b ofs ->
    Genv.find_symbol ge id = Some b ->
    Genv.find_funct_ptr ge b = Some (Internal f) ->
    Asm.find_instr (Ptrofs.unsigned ofs) (Asm.fn_code f) = Some i ->
    RawAsm.exec_instr ge f i rs1 m1 = Next rs1' m1' ->
    transl_instr gm lm ofs' id sid i = OK i' ->
    exists rs2' m2',
      FlatAsm.exec_instr tge i' rs2 m2 = Next rs2' m2' /\
      match_states (State rs1' m1') (State rs2' m2').
Proof.
  intros. destruct i. destruct i; inv H3; simpl in *; monadInvX H4;
                        try first [solve_store_load |
                                   solve_match_states].

  - (* Pmov_rs *)
    apply nextinstr_nf_pres_inject.
    apply regset_inject_expand; auto.
    inv MATCHSMINJ.
    unfold Globalenvs.Genv.symbol_address.
    destruct (Genv.find_symbol ge id0) eqn:FINDSYM; auto.
    exploit agree_sminj_glob0; eauto.
    intros (ofs1 & b1 & b' & FSYM & GLBL & JB).
    rewrite FSYM in FINDSYM; inv FINDSYM. 
    rewrite GLBL.
    rewrite <- (Ptrofs.add_zero_l ofs1).
    eapply Val.inject_ptr; eauto.
    rewrite Ptrofs.repr_unsigned. auto.

  (* Divisions *)
  - unfold Asm.exec_instr in H6; simpl in H6.
    destr_match_outcome. 
    generalize (RSINJ Asm.RDX). generalize (RSINJ Asm.RAX). generalize (RSINJ r1).
    rewrite EQ, EQ0, EQ1. inversion 1; subst. inversion 1; subst. inversion 1; subst.
    eexists; eexists. split. simpl. setoid_rewrite <- H10. setoid_rewrite <- H8.
    setoid_rewrite <- H6. rewrite EQ2. auto.
    eapply match_states_intro; eauto with inject_db.

  - unfold Asm.exec_instr in H6; simpl in H6.
    destr_match_outcome. 
    generalize (RSINJ Asm.RDX). generalize (RSINJ Asm.RAX). generalize (RSINJ r1).
    rewrite EQ, EQ0, EQ1. inversion 1; subst. inversion 1; subst. inversion 1; subst.
    eexists; eexists. split. simpl. setoid_rewrite <- H10. setoid_rewrite <- H8.
    setoid_rewrite <- H6. rewrite EQ2. auto.
    eapply match_states_intro; eauto with inject_db.

  - unfold Asm.exec_instr in H6; simpl in H6.
    destr_match_outcome. 
    generalize (RSINJ Asm.RDX). generalize (RSINJ Asm.RAX). generalize (RSINJ r1).
    rewrite EQ, EQ0, EQ1. inversion 1; subst. inversion 1; subst. inversion 1; subst.
    eexists; eexists. split. simpl. setoid_rewrite <- H10. setoid_rewrite <- H8.
    setoid_rewrite <- H6. rewrite EQ2. auto.
    eapply match_states_intro; eauto with inject_db.

  - unfold Asm.exec_instr in H6; simpl in H6.
    destr_match_outcome. 
    generalize (RSINJ Asm.RDX). generalize (RSINJ Asm.RAX). generalize (RSINJ r1).
    rewrite EQ, EQ0, EQ1. inversion 1; subst. inversion 1; subst. inversion 1; subst.
    eexists; eexists. split. simpl. setoid_rewrite <- H10. setoid_rewrite <- H8.
    setoid_rewrite <- H6. rewrite EQ2. auto.
    eapply match_states_intro; eauto with inject_db.
     
  - (* Pcmov *)
    unfold Asm.exec_instr in H6; simpl in H6.
    exploit (eval_testcond_inject j c rs1 rs2); eauto.
    intros. 
    destr_eval_testcond; try solve_match_states.
    destruct (Asm.eval_testcond c rs2) eqn:EQ'. destruct b0; solve_match_states.
    solve_match_states.

  - (* Pjmp_l *)
    unfold Asm.exec_instr in H6; simpl in H6.
    unfold Asm.goto_label in H6. destruct (label_pos l 0 (Asm.fn_code f)) eqn:LBLPOS; inv H6.
    destruct (rs1 Asm.PC) eqn:PC1; inv H4. 
    destruct (Genv.find_funct_ptr ge b0); inv H5.
    eexists; eexists. split. simpl.
    unfold goto_label. eauto.
    eapply match_states_intro; eauto.
    apply regset_inject_expand; auto. 
    rewrite H in *. inv PC1. inv H.
    eapply agree_sminj_lbl; eauto.

  - (* Pjmp_s *)
    apply regset_inject_expand; auto.
    inversion MATCHSMINJ. 
    exploit (agree_sminj_glob0 symb s0); eauto.
    intros (ofs1 & b1 & b' & FSYM & LBLOFS & JB). 
    unfold Globalenvs.Genv.symbol_address. rewrite FSYM. 
    rewrite LBLOFS. econstructor; eauto.
    simpl_goal. auto.

  - (* Pjcc *)
    unfold Asm.exec_instr in H6; simpl in H6.
    exploit (eval_testcond_inject j c rs1 rs2); eauto.
    intros.
    destr_eval_testcond; try solve_match_states.
    exploit goto_label_inject; eauto. intros (rs2' & GOTO & RINJ' & MINJ').
    exists rs2', m2. split. simpl. rewrite <- H7. auto.
    eapply match_states_intro; eauto.
    assert (m1 = m1') by (eapply goto_label_pres_mem; eauto). subst. auto.

  - (* Pjcc2 *)
    unfold Asm.exec_instr in H6; simpl in H6.
    exploit (eval_testcond_inject j c1 rs1 rs2); eauto.
    exploit (eval_testcond_inject j c2 rs1 rs2); eauto.
    intros ELF1 ELF2.
    destr_eval_testcond; try solve_match_states.
    exploit goto_label_inject; eauto. intros (rs2' & GOTO & RINJ' & MINJ').
    exists rs2', m2. split. simpl. setoid_rewrite <- H5. setoid_rewrite <- H7. auto.
    eapply match_states_intro; eauto.
    assert (m1 = m1') by (eapply goto_label_pres_mem; eauto). subst. auto.

  - (* Pjmptbl *)
    unfold Asm.exec_instr in H6; simpl in H6.
    destruct (rs1 r) eqn:REQ; inv H6.
    destruct (list_nth_z tbl (Int.unsigned i)) eqn:LEQ; inv H4.
    assert (rs2 r = Vint i) by
        (generalize (RSINJ r); rewrite REQ; inversion 1; auto).
    exploit (goto_tbl_label_inject gm lm id tbl x0 l); eauto. 
    intros (rs2' & l' & LEQ' & GLBL & RSINJ' & MINJ').
    exists rs2', m2. split. simpl. setoid_rewrite H3. setoid_rewrite LEQ'. auto. 
    eapply match_states_intro; eauto.
    assert (m1 = m1') by (eapply goto_label_pres_mem; eauto). subst. auto.
    
  - (* Pcall_s *)
    generalize (RSINJ PC). intros. rewrite H in *. inv H3.
    repeat apply regset_inject_expand; auto.
    + apply Val.offset_ptr_inject. eauto.
    + exploit (inject_symbol_sectlabel gm lm j symb s0 Ptrofs.zero); eauto. 
      
  - (* Pallocframe *)
    generalize (RSINJ RSP). intros RSPINJ.
    destruct (Mem.storev Mptr m1
                         (Val.offset_ptr
                            (Val.offset_ptr (rs1 RSP)
                                            (Ptrofs.neg (Ptrofs.repr (align (frame_size frame) 8))))
                            ofs_ra) (rs1 RA)) eqn:STORERA; try inv H6.
    exploit (fun a1 a2 =>
               storev_mapped_inject' j Mptr m1 a1 (rs1 RA) m1' m2 a2 (rs2 RA)); eauto with inject_db.
    intros (m2' & STORERA' & MINJ2).
    destruct (rs1 RSP) eqn:RSP1; simpl in *; try congruence.
    inv RSPINJ.
    eexists; eexists.
    (* Find the resulting state *)
    rewrite <- H5 in STORERA'. rewrite STORERA'. split. eauto.
    (* Solve match states *)
    eapply match_states_intro; eauto.
    eapply nextinstr_pres_inject; eauto.
    repeat eapply regset_inject_expand; eauto.
    eapply Val.inject_ptr; eauto.
    repeat rewrite (Ptrofs.add_assoc i).
    rewrite (Ptrofs.add_commut (Ptrofs.repr delta)). auto.
    eapply store_pres_glob_block_valid; eauto.

  - (* Pfreeframe *)
    generalize (RSINJ RSP). intros.
    destruct (Mem.loadv Mptr m1 (Val.offset_ptr (rs1 RSP) ofs_ra)) eqn:EQRA; try inv H6.
    exploit (fun g a2 => Mem.loadv_inject j g m1' m2 Mptr (Val.offset_ptr (rs1 Asm.RSP) ofs_ra) a2 v); eauto.
    apply Val.offset_ptr_inject. auto.
    intros (v2 & MLOAD2 & VINJ2).
    eexists; eexists. split. simpl.
    setoid_rewrite MLOAD2. auto.
    eapply match_states_intro; eauto with inject_db.

Qed.


Theorem step_simulation:
  forall S1 t S2,
    RawAsm.step ge S1 t S2 ->
    forall S1' (MS: match_states S1 S1'),
    exists S2',
      FlatAsm.step tge S1' t S2' /\
      match_states S2 S2'.
Proof.
  destruct 1; intros; inv MS.

  - (* Internal step *)
    unfold regset_inject in RSINJ. generalize (RSINJ Asm.PC). rewrite H. 
    inversion 1; subst.
    exploit (agree_sminj_instr gm lm j MATCHSMINJ b b2 f ofs delta i); eauto.
    intros (id & i' & sid & ofs1 & FITARG & FSYMB & TRANSL).
    exploit (exec_instr_step j rs rs'0 m m'0 rs' m' gm lm i i' id); eauto.
    intros (rs2' & m2' & FEXEC & MS1).
    exists (State rs2' m2'). split; auto.
    eapply FlatAsm.exec_step_internal; eauto.
        
  - (* Builtin *)
    unfold regset_inject in RSINJ. generalize (RSINJ Asm.PC). rewrite H.
    inversion 1; subst.
    exploit (agree_sminj_instr gm lm j MATCHSMINJ b b2 f ofs delta (Asm.Pbuiltin ef args res, sz)); auto.
    intros (id & i' & sid & ofs1 & FITARG & FSYMB & TRANSL).
    (* exploit (globs_to_funs_inj_into_flatmem j); eauto. inversion 1; subst. *)
    monadInv TRANSL. monadInv EQ.
    set (pbseg := {| segblock_id := sid; segblock_start := Ptrofs.repr ofs1; segblock_size := Ptrofs.repr (si_size sz) |}) in *.
    exploit (eval_builtin_args_inject gm lm j m m'0 rs rs'0 (rs Asm.RSP) (rs'0 Asm.RSP) args vargs x0); auto.
    intros (vargs' & EBARGS & ARGSINJ).
    generalize (external_call_inject j vargs vargs' m m'0 m' vres t ef ARGSINJ MINJ H3).
    intros (j' & vres2 & m2' & EXTCALL & RESINJ & MINJ' & INJINCR & INJSEP).
    set (rs' := nextinstr_nf (set_res res vres2 (undef_regs (map preg_of (Machregs.destroyed_by_builtin ef)) rs'0)) (segblock_size pbseg)).
    exploit (fun b ofs => FlatAsm.exec_step_builtin tge b ofs
                                       ef x0 res rs'0  m'0 vargs' t vres2 rs' m2' pbseg); eauto. 
    (* unfold valid_instr_offset_is_internal in INSTRINTERNAL. *)
    (* eapply INSTRINTERNAL; eauto. *)
    intros FSTEP. eexists; split; eauto.
    eapply match_states_intro with (j:=j'); eauto.
    (* Supposely the following propreties can proved by separation property of injections *)
    + eapply (inject_pres_match_sminj j); eauto.
    (* + eapply (inject_pres_globs_inj_into_flatmem j); eauto. *)
    + eapply (inject_pres_valid_instr_offset_is_internal j); eauto.
    + eapply (inject_pres_extfun_entry_is_external j); eauto.
    + eapply (inject_pres_match_find_funct j); eauto.
    + subst rs'. intros. subst pbseg; simpl.
      assert (regset_inject j' rs rs'0) by 
          (eapply regset_inject_incr; eauto).
      set (dregs := (map Asm.preg_of (Machregs.destroyed_by_builtin ef))) in *.
      generalize (undef_regs_pres_inject j' rs rs'0 dregs H5). intros.
      set (rs1 := (Asm.undef_regs dregs rs)) in *.
      set (rs2 := (Asm.undef_regs dregs rs'0)) in *.
      generalize (fun h => set_res_pres_inject res j' 
                  rs1 rs2 h vres vres2 RESINJ).
      set (rs3 := (Asm.set_res res vres rs1)) in *.
      set (rs4 := (Asm.set_res res vres2 rs2)) in *.
      intros.
      eauto with inject_db.
    + eapply extcall_pres_glob_block_valid; eauto.

  - (* External call *)
    unfold regset_inject in RSINJ. generalize (RSINJ Asm.PC). rewrite H. 
    inversion 1; subst. rewrite Ptrofs.add_zero_l in H6.
    (* exploit (globs_to_funs_inj_into_flatmem j); eauto. inversion 1; subst. *)
    generalize (extcall_arguments_inject rs rs'0 m m'0 ef args j H1 MINJ RSINJ).
    intros (args2 & ARGSINJ & EXTCALLARGS).
    exploit (external_call_inject j args args2 m m'0 m' res t ef); eauto.
    intros (j' & res' & m2' & EXTCALL & RESINJ & MINJ' & INJINCR & INJSEP).
    exploit (fun ofs => FlatAsm.exec_step_external tge b2 ofs ef args2 res'); eauto.
    + generalize (RSINJ Asm.RSP). intros. 
      eapply vinject_pres_has_type; eauto.
    + generalize (RSINJ Asm.RA). intros. 
      eapply vinject_pres_has_type; eauto.
    + generalize (RSINJ Asm.RSP). intros. 
      eapply vinject_pres_not_vundef; eauto.
    + generalize (RSINJ Asm.RA). intros. 
      eapply vinject_pres_not_vundef; eauto.
    + intros FSTEP. eexists. split. apply FSTEP.
      eapply match_states_intro with (j := j'); eauto.
      * eapply (inject_pres_match_sminj j); eauto.
      (* * eapply (inject_pres_globs_inj_into_flatmem j); eauto. *)
      * eapply (inject_pres_valid_instr_offset_is_internal j); eauto.
      * eapply (inject_pres_extfun_entry_is_external j); eauto.
      * eapply (inject_pres_match_find_funct j); eauto.
      * assert (regset_inject j' rs rs'0) by 
            (eapply regset_inject_incr; eauto).
        set (dregs := (map Asm.preg_of Conventions1.destroyed_at_call)) in *.
        generalize (undef_regs_pres_inject j' rs rs'0 dregs H4). intros.
        set (rs1 := (Asm.undef_regs dregs rs)) in *.
        set (rs2 := (Asm.undef_regs dregs rs'0)) in *.
        set (cdregs := (CR Asm.ZF :: CR Asm.CF :: CR Asm.PF :: CR Asm.SF :: CR Asm.OF :: nil)) in *.
        generalize (undef_regs_pres_inject j' rs1 rs2 cdregs). intros.
        set (rs3 := (Asm.undef_regs cdregs rs1)) in *.
        set (rs4 := (Asm.undef_regs cdregs rs2)) in *.
        generalize (set_pair_pres_inject j' rs3 rs4 res res' 
                                         (Asm.loc_external_result (ef_sig ef))).
        intros.
        apply regset_inject_expand; auto.
        apply regset_inject_expand; auto.
    * eapply extcall_pres_glob_block_valid; eauto.
Qed.        

Lemma transf_final_states:
  forall st1 st2 r,
  match_states st1 st2 -> Asm.final_state st1 r -> FlatAsm.final_state st2 r.
Proof.
  intros st1 st2 r MATCH FINAL.
  inv FINAL. inv MATCH. constructor. 
  - red in RSINJ. generalize (RSINJ PC). rewrite H. 
    unfold Vnullptr. destruct Archi.ptr64; inversion 1; auto.
  - red in RSINJ. generalize (RSINJ RAX). rewrite H0.
    inversion 1. auto.
Qed.
  

Theorem transf_program_correct:
  forward_simulation (RawAsm.semantics prog (Pregmap.init Vundef)) (FlatAsm.semantics tprog (Pregmap.init Vundef)).
Proof.
  eapply forward_simulation_step with match_states.
  - simpl. admit.
  - simpl. intros s1 IS. 
    exploit transf_initial_states; eauto.
  - simpl. intros s1 s2 r MS FS. eapply transf_final_states; eauto.
  - simpl. intros s1 t s1' STEP s2 MS. 
    edestruct step_simulation as (STEP' & MS'); eauto.
Admitted.

End PRESERVATION.


End WITHMEMORYMODEL.