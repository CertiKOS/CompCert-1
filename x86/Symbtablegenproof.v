(* *******************  *)
(* Author: Yuting Wang  *)
(* Date:   Dec 2, 2019 *)
(* *******************  *)

Require Import Coqlib Errors Maps.
Require Import Integers Floats AST Linking.
Require Import Values Memory Events Globalenvs Smallstep.
Require Import Op Locations Mach Conventions Asm RealAsm.
Require Import Symbtablegen.
Require Import RelocProgram RelocProgSemantics.
Require Import LocalLib AsmInject.
Require Import Symbtablegenproof1.
Import ListNotations.
Require AsmFacts.

Open Scope Z_scope.

Hint Resolve in_eq in_cons.


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

Lemma alignw_divides:
  forall z,
    (alignw | align z alignw).
Proof.
  intros. apply align_divides. unfold alignw; omega.
Qed.

Lemma fold_left_acc_symb_acc:
  forall defs stbl dofs cofs stbl' dofs' cofs',
    fold_left (acc_symb sec_data_id sec_code_id) defs (stbl, dofs, cofs) = (stbl', dofs', cofs') ->
    forall se,
      In se stbl -> In se stbl'.
Proof.
  induction defs; simpl; intros; eauto. inv H; auto.
  repeat destr_in H.
  eapply IHdefs. eauto. right. auto.
Qed.

Lemma gen_symb_table_ok:
  forall id d defs defs1 defs2 stbl dofs cofs stbl' dofs' cofs',
    defs = defs1 ++ (id, d) :: defs2 ->
    list_norepet (map fst defs) ->
    fold_left (acc_symb sec_data_id sec_code_id) defs (stbl, dofs, cofs) = (stbl', dofs', cofs') ->
    exists dofs1 cofs1 stbl1,
      fold_left (acc_symb sec_data_id sec_code_id) defs1 (stbl, dofs, cofs) = (stbl1, dofs1, cofs1) /\
      In (get_symbentry sec_data_id sec_code_id dofs1 cofs1 id d) stbl'.
Proof.
  induction defs; simpl; intros defs1 defs2 stbl dofs cofs stbl' dofs' cofs' SPLIT NR FL; eauto.
  - apply (f_equal (@length _)) in SPLIT.
    rewrite app_length in SPLIT. simpl in SPLIT. omega.
  - repeat destr_in FL.
    destruct (ident_eq i id).
    + subst.
      assert (defs1 = []). destruct defs1. auto. simpl in SPLIT. inv SPLIT.
      simpl in NR.
      inv NR.
      exfalso; apply H2. rewrite map_app. rewrite in_app. right. simpl. auto. subst.
      simpl in *. inv SPLIT.
      (do 3 eexists); split; eauto.
      eapply fold_left_acc_symb_acc. eauto. left; auto.
    + destruct defs1. simpl in SPLIT. inv SPLIT. congruence.
      simpl in SPLIT. inv SPLIT.
      edestruct IHdefs as (dofs1 & cofs1 & stbl1 & FL1 & IN1). eauto.
      inv NR. auto. eauto.
      simpl. rewrite Heqp0.
      setoid_rewrite FL1.
      (do 3 eexists); split; eauto.
Qed.

Lemma symb_table_ok:
  forall id d defs dofs cofs stbl defs1 defs2,
    defs = defs1 ++ (id, d) :: defs2 ->
    list_norepet (map fst defs) ->
    gen_symb_table sec_data_id sec_code_id defs = (stbl, dofs, cofs) ->
    exists stbl1 dofs1 cofs1,
      gen_symb_table sec_data_id sec_code_id defs1 = (stbl1, dofs1, cofs1) /\
      In (get_symbentry sec_data_id sec_code_id dofs1 cofs1 id d) stbl.
Proof.
  intros.
  unfold gen_symb_table in H1. repeat destr_in H1.
  setoid_rewrite <- in_rev.
  eapply gen_symb_table_ok in Heqp; eauto.
  destruct Heqp as (dofs1 & cofs1 & stbl1 & FL1 & IN1).
  unfold gen_symb_table. setoid_rewrite FL1.
  (do 3 eexists); split; eauto.
Qed.

Lemma symb_table_ok':
  forall id d defs dofs cofs stbl,
    list_norepet (map fst defs) ->
    In (id, d) defs ->
    gen_symb_table sec_data_id sec_code_id defs = (stbl, dofs, cofs) ->
    exists dofs1 cofs1,
      In (get_symbentry sec_data_id sec_code_id dofs1 cofs1 id d) stbl.
Proof.
  intros.
  edestruct in_split as (defs1 & defs2 & SPLIT); eauto.
  edestruct symb_table_ok as (stbl1 & cofs1 & dofs1 & DST & IN); eauto.
Qed.

(** Properties about Symbol Environments *)
Lemma add_external_global_pres_senv :
  forall e (ge : Genv.t) extfuns,
  Genv.genv_senv (add_external_global extfuns ge e) = Genv.genv_senv ge.
Proof.
  intros. unfold add_external_global.
  destr.
Qed.

Lemma add_external_globals_pres_senv :
  forall stbl (ge : Genv.t) extfuns,
  Genv.genv_senv (add_external_globals extfuns ge stbl) = Genv.genv_senv ge.
Proof.
  induction stbl; intros.
  - simpl. auto.
  - simpl. erewrite IHstbl; eauto.
Qed.

Lemma transf_prog_pres_senv: forall p tp,
  transf_program p = OK tp -> 
  Globalenvs.Genv.to_senv (Globalenvs.Genv.globalenv p) = Genv.genv_senv (globalenv tp).
Proof.
  intros p tp TF.
  unfold transf_program in TF.
  destr_in TF. destr_in TF.
  destruct p0.
  destr_in TF.
  inv TF. cbn.
  rewrite add_external_globals_pres_senv.
  cbn. auto.
Qed.




(** * Main Preservaiton Proofs *)
Section PRESERVATION.

Context `{memory_model: Mem.MemoryModel }.
Context `{external_calls_prf: !ExternalCallsOps mem}.
Existing Instance inject_perm_all.

Local Existing Instance mem_accessors_default.


(** Assumption about external calls.
    These should be merged into common properties about external calls later. *)
Axiom external_call_inject : forall ge j vargs1 vargs2 m1 m2 m1' vres1 t ef,
    Val.inject_list j vargs1 vargs2 ->
    Mem.inject j (def_frame_inj m1) m1 m2 ->
    external_call ef ge vargs1 m1 t vres1 m1' ->
    exists j' vres2 m2',
      external_call ef ge vargs2 m2 t vres2 m2' /\
      Val.inject j' vres1 vres2 /\ Mem.inject j' (def_frame_inj m1') m1' m2' /\
      inject_incr j j' /\
      inject_separated j j' m1 m2.

Axiom  external_call_valid_block: forall ef ge vargs m1 t vres m2 b,
    external_call ef ge vargs m1 t vres m2 -> Mem.valid_block m1 b -> Mem.valid_block m2 b.


Lemma prog_instr_valid: forall prog tprog,
    transf_program prog = OK tprog ->
    Forall def_instrs_valid (map snd (AST.prog_defs prog)).
Proof.
  intros prog tprog TRANSF.
  unfold transf_program in TRANSF.
  destr_in TRANSF.
  inv w. auto.
Qed.

Lemma int_funct_instr_valid: forall prog tprog f b,
    transf_program prog = OK tprog ->
    Globalenvs.Genv.find_funct_ptr (Genv.globalenv prog) b = Some (Internal f) ->
    Forall instr_valid (Asm.fn_code f).
Proof.
  intros prog tprog f b TF FIND.
  generalize (prog_instr_valid _ _ TF).
  intros NJ.
  generalize (Genv.find_funct_ptr_inversion _ _ FIND).
  intros (id, IN).
  generalize (in_map snd _ _ IN).
  cbn. intros IN'.
  rewrite Forall_forall in NJ.
  apply NJ in IN'.
  red in IN'. auto.
Qed.

Lemma instr_is_valid: forall prog tprog f b i ofs,
    transf_program prog = OK tprog ->
    Globalenvs.Genv.find_funct_ptr (Genv.globalenv prog) b = Some (Internal f) ->
    Asm.find_instr ofs (Asm.fn_code f) = Some i ->
    instr_valid i.
Proof.
  intros prog tprog f b i ofs TF FIND FIND'.
  generalize (int_funct_instr_valid _ _ _ _ TF FIND).
  intros NJ.
  rewrite Forall_forall in NJ.
  auto. 
  apply NJ. 
  eapply Asmgenproof0.find_instr_in; eauto.
Qed.
  


(** Transformation *)
Variable prog: Asm.program.
Variable tprog: program.

Let ge := Genv.globalenv prog.
Let tge := globalenv tprog.

Definition match_prog (p: Asm.program) (tp: program) :=
  transf_program p = OK tp.

Hypothesis TRANSF: match_prog prog tprog.


(** ** Definitions of Matching States *)

Definition glob_block_valid (m:mem) := 
  forall b g, Globalenvs.Genv.find_def ge b = Some g -> Mem.valid_block m b.

(** Properties about the memory injection from RealAsm to Relocatable Programs *)   Record match_inj (j: meminj) : Type :=
  {
    (** Preservation of finding of instruction *)
    agree_inj_instrs:
      forall b b' f ofs ofs' i,
        Globalenvs.Genv.find_funct_ptr ge b = Some (Internal f) -> 
        Asm.find_instr (Ptrofs.unsigned ofs) (Asm.fn_code f) = Some i ->
        j b = Some (b', ofs') -> 
        Genv.find_instr tge (Vptr b' (Ptrofs.add ofs (Ptrofs.repr ofs'))) = Some i;

    (** Preservation of finding of global symbols *)
    agree_inj_globs:
      forall id b,
        Globalenvs.Genv.find_symbol ge id = Some b ->
        exists b' ofs', Genv.find_symbol tge id = Some (b', ofs') /\
                   j b = Some (b', Ptrofs.unsigned ofs');

    (** Preservation of finding of external functions *)
    agree_inj_ext_funct:
      forall b f ofs b',
        Globalenvs.Genv.find_funct_ptr ge b = Some (External f) ->
        j b = Some (b', ofs) ->
        Genv.find_ext_funct tge (Vptr b' (Ptrofs.repr ofs)) = Some f;

    (** Preservation of finding of internal functions *)
    agree_inj_int_funct:
      forall b f ofs b' ofs',
        Globalenvs.Genv.find_funct_ptr ge b = Some (Internal f) ->
        j b = Some (b', ofs) ->
        Genv.find_ext_funct tge (Vptr b' ofs') = None;
  }.


(** Match States *)
Inductive match_states: state -> state -> Prop :=
| match_states_intro: forall (j:meminj) (rs: regset) (m: mem) (rs': regset) (m':mem)
                        (MINJ: Mem.inject j (def_frame_inj m) m m')
                        (MATCHINJ: match_inj j)
                        (RSINJ: regset_inject j rs rs')
                        (GBVALID: glob_block_valid m),
    match_states (State rs m) (State rs' m').


(** ** Matching of the Initial States *)

Lemma symbol_address_inject : forall j id ofs
                                (MATCHINJ: match_inj j),
    Val.inject j (Senv.symbol_address ge id ofs) (Genv.symbol_address tge id ofs).
Proof.
  intros. unfold Senv.symbol_address.
  inv MATCHINJ.
  unfold Senv.find_symbol. simpl.
  destruct (Globalenvs.Genv.find_symbol ge id) eqn:FINDSYM; auto.
  exploit agree_inj_globs0; eauto.
  intros (b' & ofs' & FINDSYM' & JB).
  erewrite Genv.symbol_address_offset; eauto. 
  eapply Val.inject_ptr; eauto.
  rewrite Ptrofs.repr_unsigned. apply Ptrofs.add_commut.
  unfold Genv.symbol_address. rewrite FINDSYM'. 
  rewrite Ptrofs.add_zero_l. auto.
Qed.

(** Initial Memory Injection *)
Definition init_meminj : meminj :=
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
        match Genv.find_symbol tge id with
        | None => None
        | Some (b,ofs) => Some (b, Ptrofs.unsigned ofs)
        end
      end.

Lemma acc_symb_map_inv : forall e t b ofs,
    t ! (symbentry_id e) = None ->
    (acc_symb_map e t) ! (symbentry_id e) = Some (b, ofs) ->
    ofs = Ptrofs.repr (symbentry_value e) /\
    (exists i : N,
        symbentry_secindex e = secindex_normal i /\
        b = sec_index_to_block i).
Proof.
  intros e t b ofs GET ACC.
  unfold acc_symb_map in ACC.
  destr_in ACC.
  erewrite PTree.gss in ACC. inv ACC.
  eauto.
Qed.

Lemma acc_symb_map_no_effect: forall stbl id t,
    ~In id (get_symbentry_ids stbl) ->
    (fold_right acc_symb_map t stbl) ! id = t ! id.
Proof.
  induction stbl as [|e stbl].
  - cbn. auto.
  - cbn. intros id t NIN.
    unfold acc_symb_map.
    destr; auto.
    destruct (peq (symbentry_id e) id); subst; eauto.
    + tauto.
    + erewrite PTree.gso; eauto.
Qed.

Lemma symbtable_to_tree_acc_symb_map_inv': forall stbl id e b ofs t,
    list_norepet (get_symbentry_ids stbl) ->
    (PTree_Properties.of_list (symbtable_to_idlist stbl)) ! id = Some e ->
    t ! id = None ->
    (fold_right acc_symb_map t stbl) ! id = Some (b, ofs) ->
    ofs = Ptrofs.repr (symbentry_value e) /\
    (exists i, symbentry_secindex e = secindex_normal i /\ b = sec_index_to_block i).
Proof.
  induction stbl as [|e stbl].
  - cbn. intros.
    congruence.
  - intros id e0 b ofs t NORPT T NG ACC.
    unfold get_symbentry_ids in NORPT.
    inv NORPT.
    cbn [symbtable_to_idlist map] in T.
    cbn in ACC.
    destruct (peq id (symbentry_id e)).
    + subst.
      rewrite PTree_Properties_of_list_cons in T. inv T.
      apply acc_symb_map_inv with (fold_right acc_symb_map t stbl); eauto.     
      erewrite acc_symb_map_no_effect; eauto.
      rewrite list_map_compose. cbn. auto.
    + erewrite PTree_Properties_of_list_tail in T; eauto. 
      eapply IHstbl; eauto.
      unfold acc_symb_map in ACC.
      destr_in ACC; auto.
      erewrite PTree.gso in ACC; eauto.
Qed.

Lemma symbtable_to_tree_acc_symb_map_inv: forall stbl id e b ofs,
    list_norepet (get_symbentry_ids stbl) ->
    (symbtable_to_tree stbl) ! id = Some e ->
    (fold_right acc_symb_map (PTree.empty _) stbl) ! id = Some (b, ofs) ->
    ofs = Ptrofs.repr (symbentry_value e) /\
    (exists i, symbentry_secindex e = secindex_normal i /\ b = sec_index_to_block i).
Proof.
  unfold symbtable_to_tree.
  intros. eapply symbtable_to_tree_acc_symb_map_inv'; eauto.
  rewrite PTree.gempty; auto.
Qed.


Lemma acc_instr_map_no_effect: forall c ofs' ofs map cz map',
    fold_left acc_instr_map c (ofs', map') = (cz, map) ->
    (Ptrofs.unsigned ofs) < (Ptrofs.unsigned ofs') ->
    map ofs = map' ofs.
Proof.
  induction c as [|i c].
  - cbn. intros. inv H. auto.
  - cbn. intros ofs' ofs map cz map' ACC LE.
    assert (Ptrofs.unsigned ofs < Ptrofs.unsigned (Ptrofs.add ofs' (Ptrofs.repr (instr_size i)))) as LE'.
    { 
      rewrite Ptrofs.add_unsigned.
      repeat rewrite Ptrofs.unsigned_repr. 
      generalize (instr_size_positive i). omega.
      apply instr_size_repr.
      admit.
      apply instr_size_repr.
    }
    generalize (IHc _ _ _ _ _ ACC LE').
    intros MAP'.
    rewrite MAP'.
    destr. subst. omega.
Admitted.

Lemma acc_instr_map_pres_find : forall c i ofs ofs' map map' cz,
    find_instr ofs c = Some i ->
    fold_left acc_instr_map c (ofs', map') = (cz, map) ->
    map (Ptrofs.add ofs' (Ptrofs.repr ofs)) = Some i.
Proof.
  induction c as [|i c].
  - cbn. intros. congruence.
  - intros i1 ofs ofs' map map' cz FIND ACC.
    cbn in FIND. destruct zeq. subst.
    + inv FIND. 
      rewrite Ptrofs.add_zero.
      cbn in ACC.
      erewrite acc_instr_map_no_effect; eauto.
      cbn. destruct Ptrofs.eq_dec; congruence.
      rewrite Ptrofs.add_unsigned.
      rewrite Ptrofs.unsigned_repr. 
      generalize (Ptrofs.unsigned_range (Ptrofs.repr (instr_size i1))).
      rewrite Ptrofs.unsigned_repr. 
      generalize (instr_size_positive i1). omega.
      apply instr_size_repr.
      admit.
    + cbn in ACC.
      exploit IHc; eauto.
      intros MAP.
      rewrite Ptrofs.add_assoc in MAP.
      rewrite <- MAP. f_equal. f_equal.
      rewrite Ptrofs.add_unsigned. 
      rewrite Ptrofs.unsigned_repr. 
      rewrite Ptrofs.unsigned_repr. 
      f_equal. omega.
      admit.
      apply instr_size_repr.
Admitted.


Lemma acc_symb_map_size: forall c ofs map cz map',
    fold_left acc_instr_map c (ofs, map) = (cz, map') -> 
    cz = Ptrofs.add ofs (Ptrofs.repr (code_size c)).
Proof.
  induction c as [|i c].
  - cbn; intros. inv H. rewrite Ptrofs.add_zero. auto.
  - intros ofs map cz map' ACC.
    cbn in ACC.
    apply IHc in ACC. subst.
    rewrite Ptrofs.add_assoc.
    f_equal.
    rewrite Ptrofs.add_unsigned. 
    rewrite Ptrofs.unsigned_repr. 
    rewrite Ptrofs.unsigned_repr. auto.
    admit.
    apply instr_size_repr.
Admitted.


Lemma code_size_bound: forall defs (id:ident) f,
    In (id, Some (Gfun (Internal f))) defs ->
    code_size (fn_code f) <= odefs_size (map snd defs).
Proof.
  induction defs as [|def defs].
  - cbn. intros. contradiction.
  - cbn. intros id f [EQ | IN].
    + subst. cbn. 
      generalize (odefs_size_pos (map snd defs)).
      intros LE.
      apply le_add_pos. auto.
    + generalize (IHdefs _ _ IN).
      intros. etransitivity; eauto.
      rewrite Z.add_comm. apply le_add_pos.      
      eapply odef_size_pos.
Qed.

Lemma def_code_size_le_odef_size : forall def, 
    def_code_size def <= odef_size def.
Proof.
  intros. destruct def. destruct g. destruct f.
  cbn. omega.
  cbn. omega.
  cbn. generalize (init_data_list_size_pos (gvar_init v)). omega.
  cbn. omega.
Qed.

Lemma pres_find_instr_aux: forall (defs: list (ident * option (globdef fundef unit))) id f ofs i cz t ofs' t',
    list_norepet (map fst defs) ->
    In (id, Some (Gfun (Internal f))) defs ->
    find_instr (Ptrofs.unsigned ofs) (fn_code f) = Some i ->
    (cz, t) = fold_left acc_instr_map (fold_right acc_instrs [] defs) (ofs', t') ->
    t (Ptrofs.add ofs (Ptrofs.add ofs' (Ptrofs.repr (defs_code_size (defs_before id defs))))) = Some i.
Proof.
  induction defs as [|def defs].
  - intros.
    cbn in *. contradiction.
  - intros id f ofs i cz t ofs' t' NORPT IN FIND ACC.
    assert (Ptrofs.unsigned ofs' + odefs_size (map snd (def::defs)) <= Ptrofs.max_unsigned) as SZ. 
    { admit. }
    inv NORPT.
    generalize (code_size_bound _ _ _ IN). intros CBN.
    assert (Ptrofs.unsigned ofs' + code_size (fn_code f) <= Ptrofs.max_unsigned) as CBN1.
    { etransitivity; eauto. 
      rewrite <- Z.add_le_mono_l. auto. }
    assert (0 <= code_size (fn_code f) <= Ptrofs.max_unsigned) as CRNG.
    { split. generalize (code_size_non_neg (fn_code f)). omega.
      generalize (Ptrofs.unsigned_range ofs'). intros. inv H.
      etransitivity. exact CBN.
      apply Z_le_add_l_inv with (Ptrofs.unsigned ofs'); auto. }
    generalize (find_instr_bound _ _ _ FIND). intros IBND.
    generalize (instr_size_positive i). intros IPOS. 
    assert (0 <= Ptrofs.unsigned ofs + Ptrofs.unsigned ofs' <= Ptrofs.max_unsigned).
    { split.
      generalize (Ptrofs.unsigned_range ofs'). 
      generalize (Ptrofs.unsigned_range ofs); omega. omega.
    }
    inv IN.
    + cbn in ACC.
      rewrite fold_left_app in ACC.
      rewrite defs_before_head. cbn.
      rewrite Ptrofs.add_zero.
      destruct (fold_left acc_instr_map (fn_code f) (ofs', t'))
               as (cz', t'') eqn:ACC'.
      erewrite acc_instr_map_no_effect; eauto.
      rewrite Ptrofs.add_commut.
      replace ofs with ((Ptrofs.repr (Ptrofs.unsigned ofs))).
      eapply acc_instr_map_pres_find; eauto.
      erewrite Ptrofs.repr_unsigned; auto.
      exploit acc_symb_map_size; eauto.
      intros. subst. 
      rewrite Ptrofs.add_unsigned.
      rewrite Ptrofs.unsigned_repr.
      rewrite Ptrofs.add_unsigned.
      rewrite Ptrofs.unsigned_repr.
      rewrite Ptrofs.unsigned_repr; auto.
      generalize (code_size_non_neg (fn_code f)). intros. omega.
      rewrite Ptrofs.unsigned_repr; auto.
      generalize (Ptrofs.unsigned_range ofs'). omega.
      auto.
      
    + destruct def as (id', def).
      rewrite defs_before_tail.
      rewrite defs_code_size_cons.
      cbn in ACC.
      rewrite fold_left_app in ACC.
      destruct (fold_left acc_instr_map (get_def_instrs def) (ofs', t')) as (ofs'', t'') eqn:ACC1.
      exploit acc_symb_map_size; eauto. intros.
      assert (def_code_size def <= odef_size def) as DCBND.
      { eapply def_code_size_le_odef_size. }
      assert (t (Ptrofs.add ofs (Ptrofs.add ofs'' (Ptrofs.repr (defs_code_size (defs_before id defs))))) = Some i) as IHR.
      { eapply IHdefs; eauto. }
      subst. rewrite <- IHR. f_equal. f_equal.
      rewrite Ptrofs.add_assoc. f_equal.
      rewrite Ptrofs.add_unsigned. f_equal.
      repeat rewrite Ptrofs.unsigned_repr. auto.
      admit.
      admit.
      intros ID. subst. apply H1.
      rewrite in_map_iff. cbn. 
      eexists; split; eauto. cbn. auto.
Admitted.        

Lemma pres_find_instr: forall defs id f ofs i,
    list_norepet (map fst defs) ->
    In (id, Some (Gfun (Internal f))) defs ->
    find_instr (Ptrofs.unsigned ofs) (fn_code f) = Some i ->
    gen_instr_map (fold_right acc_instrs [] defs)
                  (Ptrofs.add ofs (Ptrofs.repr (defs_code_size (defs_before id defs)))) = Some i.
Proof.
  unfold gen_instr_map.
  intros. destr. 
  exploit pres_find_instr_aux; eauto.
  rewrite Ptrofs.add_zero_l. auto.
Qed.


Lemma gen_symb_table_only_internal_symbol: 
  forall did cid defs stbl dz cz id def,
    is_def_internal is_fundef_internal def = true ->
    gen_symb_table did cid defs = (stbl, dz, cz) ->
    In (id, def) defs ->
    only_internal_symbol id stbl.
  clear.
Admitted.


Theorem init_meminj_match_sminj : 
    match_inj init_meminj.
Proof.
  generalize TRANSF. intros TRANSF'.
  unfold match_prog in TRANSF'.
  unfold transf_program in TRANSF'.
  repeat destr_in TRANSF'. 
  destruct p. inv Heqp0. monadInv TRANSF'.
  revert H0. intros TL.
  constructor.

  - (* agree_inj_instrs *)
    intros b b' f ofs ofs' i FPTR FINST INITINJ.
    unfold init_meminj in INITINJ. 
    (* revert TL. *)
    destruct eq_block. inv INITINJ.
    unfold ge in FPTR. exploit Genv.genv_next_find_funct_ptr_absurd; eauto. contradiction.
    destr_match_in INITINJ; inv INITINJ.
    destr_match_in H0; inv H0.
    destruct p. inv H1. rewrite Ptrofs.repr_unsigned.
    unfold globalenv in EQ0; simpl in EQ0.
    rewrite add_external_globals_pres_find_symbol in EQ0.
    unfold Genv.find_symbol in EQ0. cbn in EQ0.
    apply Genv.invert_find_symbol in EQ.
    exploit (Genv.find_symbol_funct_ptr_inversion prog); eauto.
    intros FINPROG.
    unfold Genv.find_instr. unfold tge.
    cbn.
    rewrite add_external_globals_pres_instrs. cbn.
    unfold create_sec_table.
    replace (Pos.to_nat 1) with 1%nat by xomega.
    cbn.
    unfold gen_symb_table in Heqp.
    destr_in Heqp. destruct p. inv Heqp.
    exploit acc_symb_tree_entry_some; eauto.
    { inv w. auto. }
    { eapply PTree_Properties.of_list_norepet; eauto.
      inv w. auto. }
    cbn. intros GET.
    unfold gen_symb_map in EQ0.
    (* exploit symbtable_to_tree_acc_symb_map_sync; eauto. *)
    (* cbn. intros (EQOFS & i' & SEC & EQB). subst. *)
    (* inv SEC. *)
    (* eapply pres_find_instr; eauto. *)
    (* exploit Genv.find_symbol_funct_ptr_inversion; eauto. *)
    (* apply Genv.invert_find_symbol. eauto. eauto. intros IN. *)
    (* eapply gen_symb_table_only_internal_symbol; eauto. *)
    (* cbn. auto. *)

(*   - (* agree_inj_globs *) *)
(*     intros id b FSYM. *)
(*     unfold ge in FSYM. *)
(*     exploit Genv.find_symbol_inversion; eauto. intros INSYM. *)
(*     unfold prog_defs_names in INSYM. *)
(*     rewrite in_map_iff in INSYM. destruct INSYM as (def & EQ1 & IN). *)
(*     destruct def. simpl in EQ1. subst i. *)
(*     exploit transl_prog_pres_def; eauto. *)
(*     intros (def' & sb & IN' & TLDEF). *)
(*     exploit find_symbol_exists; eauto. *)
(*     intros (b' & ofs' & FSYM'). *)
(*     exists b', ofs'. split; auto. *)
(*     unfold init_meminj. destruct eq_block. *)
(*     subst b.  apply Genv.find_symbol_genv_next_absurd in FSYM. contradiction. *)
(*     apply Genv.find_invert_symbol in FSYM. rewrite FSYM. rewrite FSYM'. auto. *)

(* Qed. *)
Admitted.


(** Initial memory injection for global variables (not including the stacks) *)
Definition globs_meminj : meminj :=
  let ge := Genv.globalenv prog in
  let tge := globalenv tprog in
  fun b =>
      match (Genv.invert_symbol ge b) with
      | None => None
      | Some id =>
        match Genv.find_symbol tge id with
        | None => None
        | Some (b, ofs) => Some (b, Ptrofs.unsigned ofs)
        end
      end.

Lemma init_mem_pres_inject : 
  forall m
    (TRANF: transf_program prog = OK tprog)
    (INITMEM: Genv.init_mem prog = Some m),
    exists m', init_mem tprog = Some m' /\ Mem.inject globs_meminj (def_frame_inj m) m m'.
Proof.
Admitted.

(** Inversion of initial memory injection on genv_next *)
Lemma acc_symb_maps_inv : forall stbl t id b ofs,
    t ! id = None ->
    (fold_right acc_symb_map t stbl) ! id = Some (b, ofs) ->
    exists e, In e stbl /\ 
         id = symbentry_id e /\ 
         (exists i, symbentry_secindex e = secindex_normal i /\
               b = sec_index_to_block i) /\
         ofs = Ptrofs.repr (symbentry_value e).
Proof.
  induction stbl as [|e stbl].
  - intros. cbn in *. congruence.
  - intros t id b ofs NON ACC. cbn in ACC.
    unfold acc_symb_map in ACC.
    destr_in ACC.
    + destruct (peq (symbentry_id e) id).
      * subst. rewrite PTree.gss in ACC. inv ACC.
        eexists. intuition. eauto.
      * rewrite PTree.gso in ACC; auto.
        exploit IHstbl; eauto.
        intros (e' & IN & ID & (i & SI & BL) & OFS).
        subst. 
        exists e'. split; eauto.
    + exploit IHstbl; eauto.
      intros (e' & IN & ID & (i & SI & BL) & OFS).
      subst. 
      exists e'. split; eauto.
    + exploit IHstbl; eauto.
      intros (e' & IN & ID & (i & SI & BL) & OFS).
      subst. 
      exists e'. split; eauto.
Qed.        

Lemma gen_symb_table_index_range: forall did cid p stbl dz cz e i,
    gen_symb_table did cid p = (stbl, dz, cz) ->
    In e stbl -> 
    symbentry_secindex e = secindex_normal i ->
    i = did \/ i = cid.
Proof.
  intros did cid p stbl dz cz e i GEN IN SI.
  unfold gen_symb_table in GEN.
  destr_in GEN. destruct p0. inv GEN.
  exploit acc_symb_index_in_range; eauto.
  intros RNG. red in RNG.
  rewrite Forall_forall in RNG. 
  apply RNG in IN. red in IN. 
  rewrite SI in IN. inv IN; auto. inv H; auto. inv H0.
Qed.


Lemma find_symbol_globenv_block_bound :
  forall (id : ident) b ofs, Genv.find_symbol (globalenv tprog) id = Some (b, ofs) 
                        -> Pos.lt b (Genv.genv_next (globalenv tprog)).
Proof.
  unfold globalenv. simpl. intros.
  exploit add_external_globals_pres_find_symbol_block_bound; eauto. 
  red. simpl. intros.
  unfold match_prog in TRANSF. unfold transf_program in TRANSF.
  repeat destr_in TRANSF. cbn in H0.
  clear H. 
  unfold Genv.find_symbol in H0. cbn in H0.
  exploit acc_symb_maps_inv; eauto.
  apply PTree.gempty.
  intros (e & IN & ID & (i & SI & BL) & OFS). subst.
  exploit gen_symb_table_index_range; eauto.
  intros [I | I]; subst; cbn; xomega. 
Qed.

Lemma init_meminj_genv_next_inv : forall b delta
    (MINJ: init_meminj b = Some (Genv.genv_next tge, delta)),
    b = Globalenvs.Genv.genv_next ge.
Proof.
  intros.
  unfold init_meminj in MINJ. destruct eq_block; inv MINJ.
  - unfold ge. auto.
  - destr_match_in H0; inv H0.
    destr_match_in H1; inv H1.
    destruct p. inv H0.
    exploit find_symbol_globenv_block_bound; eauto.
    intros.
    exfalso. generalize H.
    setoid_rewrite <- Pos.compare_nlt_iff.
    apply Pos.lt_irrefl.
Qed.

(** Injection of main pointer *)
Lemma main_ptr_inject:
  forall (MATCH_INJ: match_inj init_meminj),
    Val.inject init_meminj
               (Globalenvs.Genv.symbol_address
                  (Globalenvs.Genv.globalenv prog)
                  (AST.prog_main prog) Ptrofs.zero)
               (Genv.symbol_address
                  (globalenv tprog)
                  (prog_main tprog) Ptrofs.zero).
Proof.
  intros.
  unfold match_prog in TRANSF. unfold transf_program in TRANSF.
  repeat destr_in TRANSF. destruct p. inv Heqp0. monadInv TRANSF.
  cbn [prog_main].
  rewrite H0. clear H0.
  inv w. auto.
  red in wf_prog_main_exists. rewrite Exists_exists in wf_prog_main_exists.
  destruct wf_prog_main_exists as (def & IN & P).
  destruct def. destruct o; destruct P as [IDEQ P]; inv P.
  cbn [prog_main].
  eapply symbol_address_inject; eauto.
Qed.



Lemma transf_initial_states : forall rs (SELF: forall j, forall r : PregEq.t, Val.inject j (rs r) (rs r)) st1,
    RealAsm.initial_state prog rs st1  ->
    exists st2, initial_state tprog rs st2 /\ match_states st1 st2.
Proof.
  intros rs SELFINJECT st1 INIT.
  generalize TRANSF. intros TRANSF'.
  unfold match_prog in TRANSF'. unfold transf_program in TRANSF'.
  destruct (check_wellformedness prog) eqn:WF. 2: congruence. repeat destr_in TRANSF'.
  rename z0 into dsize. rename z into csize. 
  inv INIT.
  generalize init_meminj_match_sminj.
  intros MATCH_SMINJ.
  exploit (init_mem_pres_inject m); eauto.
  intros (m' & INITM' & MINJ).
  inversion H0.
  (* push_new stage *)
  exploit Mem.push_new_stage_inject; eauto. intros NSTGINJ.
  exploit (Mem.alloc_parallel_inject globs_meminj (1%nat :: def_frame_inj m)
          (Mem.push_new_stage m) (Mem.push_new_stage m')
          0 (Mem.stack_limit + align (size_chunk Mptr) 8) m1 bstack
          0 (Mem.stack_limit + align (size_chunk Mptr) 8)); eauto. omega. omega.
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
  assert (forall x, j' x = init_meminj x).
  {
    intros. destruct (eq_block x bstack).
    subst x. rewrite FBSTACK. unfold init_meminj. subst.
    rewrite dec_eq_true; auto.
    erewrite NOTBSTK; eauto.
    unfold init_meminj. subst.
    rewrite dec_eq_false; auto.
  }
  exploit Mem.inject_ext; eauto. intros MINJ'.
  exploit Mem.drop_parallel_inject; eauto. red. simpl. auto.
  unfold init_meminj. fold ge. rewrite <- H3. rewrite pred_dec_true. eauto. auto.
  intros (m2' & MDROP' & DMINJ). simpl in MDROP'. rewrite Z.add_0_r in MDROP'.
  erewrite (drop_perm_pres_def_frame_inj m1) in DMINJ; eauto.
  
  assert (exists m3', Mem.record_stack_blocks m2' (make_singleton_frame_adt' bstack' RawAsm.frame_info_mono 0) = Some m3'
                 /\ Mem.inject (init_meminj) (def_frame_inj m3) m3 m3') as RCD.
  {
    unfold def_frame_inj. unfold def_frame_inj in DMINJ.
    eapply (Mem.record_stack_block_inject_flat m2 m3 m2' (init_meminj)
           (make_singleton_frame_adt' bstack RawAsm.frame_info_mono 0)); eauto.
    (* frame inject *)
    red. unfold make_singleton_frame_adt'. simpl. constructor.
    simpl. intros b2 delta FINJ.
    unfold init_meminj in FINJ. fold ge in FINJ. rewrite <- H3 in FINJ.
    rewrite pred_dec_true in FINJ; auto. inv FINJ.
    exists RawAsm.frame_info_mono. split. auto. apply inject_frame_info_id.
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
    inv H6. unfold RawAsm.frame_info_mono. simpl.
    erewrite drop_perm_perm in PERM; eauto. destruct PERM.
    eapply Mem.perm_alloc_3; eauto.
    (* in frame iff *)
    unfold make_singleton_frame_adt'. unfold in_frame. simpl.
    intros b1 b2 delta INJB. split.
    intros BEQ. destruct BEQ; try contradiction. subst b1.
    unfold init_meminj in INJB. fold ge in INJB. rewrite <- H3 in INJB.
    rewrite pred_dec_true in INJB; auto. inv INJB. left; auto.
    intros BEQ. destruct BEQ; try contradiction. subst b2.
    assert (bstack' = Mem.nextblock (Mem.push_new_stage m')) as BEQ.
    eapply Mem.alloc_result; eauto using MALLOC'.
    rewrite Mem.push_new_stage_nextblock in BEQ.
    erewrite <- init_mem_genv_next in BEQ; eauto using INITM'.
    subst bstack'.
    destruct (eq_block bstack b1); auto.
    assert (b1 <> bstack) by congruence.
    apply NOTBSTK in H4. rewrite H5 in H4. rewrite INJB in H4.
    left. symmetry. subst bstack. eapply init_meminj_genv_next_inv; eauto.

    (* top frame *)
    red. repeat rewrite_stack_blocks. constructor. auto.
    (* size stack *)
    repeat rewrite_stack_blocks.
    erewrite init_mem_stack; eauto. simpl. omega.
  }

  destruct RCD as (m3' & RCDSB & RMINJ).
  set (rs0' := rs # PC <- (Genv.symbol_address tge tprog.(prog_main) Ptrofs.zero)
                  # RA <- Vnullptr
                  # RSP <- (Vptr bstack' (Ptrofs.sub (Ptrofs.repr (Mem.stack_limit + align (size_chunk Mptr) 8)) (Ptrofs.repr (size_chunk Mptr))))) in *.
  edestruct storev_mapped_inject' as (m4' & ST & SMINJ). apply RMINJ. eauto. econstructor.
  rewrite <- H5, FBSTACK; eauto. reflexivity. constructor.
  exists (State rs0' m4'). split.
  - eapply initial_state_intro; eauto.
    eapply initial_state_gen_intro; eauto.
    subst. fold tge in MDROP'. eauto.
    subst. fold tge in MDROP'. rewrite Ptrofs.add_zero in ST. eauto.
  - eapply match_states_intro; eauto.
    (* + eapply valid_instr_offset_is_internal_init; eauto. inv w; auto. *)
    (* + eapply extfun_entry_is_external_init; eauto. inv w; auto. *)
    (* + red. *)
    (*   intros. eapply extfun_transf; eauto. inv w; auto. *)
    + red. unfold rs0, rs0'.
      apply AsmFacts.val_inject_set.
      apply AsmFacts.val_inject_set.
      apply AsmFacts.val_inject_set.
      auto.
      exploit (main_ptr_inject); eauto. unfold Globalenvs.Genv.symbol_address.
      unfold ge, ge0 in *. rewrite H1. fold tge. auto.
      unfold Vnullptr. destr; auto.
      econstructor. unfold init_meminj. subst bstack. fold ge. rewrite peq_true. subst bstack'.  fold tge. eauto.
      rewrite Ptrofs.add_zero.
      apply Ptrofs.sub_add_opp.
    + red. intros b g FD.
      unfold Genv.find_def in FD. eapply Genv.genv_defs_range in FD.
      revert FD. red. rewnb.
      fold ge. intros. xomega.
Qed.


(** ** Simulation of Single Step Execution *)

Context `{!EnableBuiltins mem}.

Lemma eval_builtin_arg_inject : forall j m m' rs rs' sp sp' arg varg
    (MATCHINJ: match_inj j)
    (MINJ: Mem.inject j (def_frame_inj m) m m')
    (RSINJ: regset_inject j rs rs')
    (VINJ: Val.inject j sp sp')
    (EVALBI: Events.eval_builtin_arg ge rs sp m arg varg),
    exists varg', eval_builtin_arg _ tge rs' sp' m' arg varg' /\
             Val.inject j varg varg'.
Proof.
  unfold regset_inject.
  induction arg; intros; inv EVALBI.
  - eexists; split; auto. constructor.
  - eexists; split; auto. constructor.
  - eexists; split; auto. constructor.
  - eexists; split; auto. constructor.
  - eexists; split; auto. constructor.
  - exploit Mem.loadv_inject; eauto.
    apply Val.offset_ptr_inject; eauto.
    intros (v2 & ML & VJ); auto.
    eexists; split. constructor. apply ML. auto.
  - eexists; split. constructor.
    apply Val.offset_ptr_inject; eauto.
  - exploit Mem.loadv_inject; eauto.
    apply symbol_address_inject; eauto.
    intros (v2 & ML & VJ); auto.
    eexists; split. constructor. apply ML. auto.
  - eexists; split. constructor.
    apply symbol_address_inject; eauto.
  - exploit IHarg1; eauto.
    intros (varg1 & EVALBI1 & JB1).
    exploit IHarg2; eauto.
    intros (varg2 & EVALBI2 & JB2).
    eexists; split. constructor; eauto.
    apply Val.longofwords_inject; auto.
Qed.

Lemma eval_builtin_args_inject : forall j m m' rs rs' sp sp' args vargs
    (MATCHINJ: match_inj j)
    (MINJ: Mem.inject j (def_frame_inj m) m m')
    (RSINJ: regset_inject j rs rs')
    (VINJ: Val.inject j sp sp')
    (EVALBI: Events.eval_builtin_args ge rs sp m args vargs),
    exists vargs', eval_builtin_args _ tge rs' sp' m' args vargs' /\
             Val.inject_list j vargs vargs'.
Proof.
  induction args; intros; simpl; inv EVALBI.
  - eexists. split. constructor. auto.
  - exploit eval_builtin_arg_inject; eauto.
    intros (varg' & EVARG & JB).
    exploit IHargs; eauto.
    intros (vargs' & EVARGS & JBS).
    exists (varg' :: vargs'). split; auto.
    unfold eval_builtin_args.
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

Lemma inject_pres_match_sminj : 
  forall j j' m1 m2 (ms: match_inj j), 
    glob_block_valid m1 -> inject_incr j j' -> inject_separated j j' m1 m2 -> 
    match_inj j'.
Proof.
  unfold glob_block_valid.
  intros. inversion ms. constructor; intros.
  -
    eapply (agree_inj_instrs0 b b'); eauto.
    unfold Globalenvs.Genv.find_funct_ptr in H2. destruct (Globalenvs.Genv.find_def ge b) eqn:FDEF; try congruence.
    exploit H; eauto. intros.
    eapply inject_decr; eauto.
  -
    exploit agree_inj_globs0; eauto.
    intros (b' & ofs' & GLBL & JB).
    eexists; eexists; eexists; eauto.
  -
    eapply (agree_inj_ext_funct0 b); eauto.
    unfold Globalenvs.Genv.find_funct_ptr in H2. destruct (Globalenvs.Genv.find_def ge b) eqn:FDEF; try congruence.
    exploit H; eauto. intros.
    eapply inject_decr; eauto.
  - 
    eapply (agree_inj_int_funct0 b); eauto.
    unfold Globalenvs.Genv.find_funct_ptr in H2. destruct (Globalenvs.Genv.find_def ge b) eqn:FDEF; try congruence.
    exploit H; eauto. intros.
    eapply inject_decr; eauto.
Qed.


Lemma inject_symbol_address : forall j id ofs,
    match_inj j ->
    Val.inject j (Globalenvs.Genv.symbol_address ge id ofs) (Genv.symbol_address tge id ofs).
Proof.
  unfold Globalenvs.Genv.symbol_address.
  intros.
  destruct (Globalenvs.Genv.find_symbol ge id) eqn:FINDSYM; auto.
  inv H. exploit agree_inj_globs0; eauto.
  intros (b' & ofs' & SBOFS & JB).
  erewrite Genv.symbol_address_offset; eauto. 
  eapply Val.inject_ptr; eauto.
  rewrite Ptrofs.repr_unsigned. apply Ptrofs.add_commut.
  unfold Genv.symbol_address. rewrite SBOFS.
  rewrite Ptrofs.add_zero_l. auto.
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

Lemma eval_addrmode32_inject: forall j a rs1 rs2,
    match_inj j ->
    regset_inject j rs1 rs2 ->
    Val.inject j (Asm.eval_addrmode32 ge a rs1) (eval_addrmode32 tge a rs2).
Proof.
  intros. unfold Asm.eval_addrmode32, eval_addrmode32.
  destruct a. 
  destruct base, ofs, const; simpl in *. 
  - destruct p. repeat apply Val.add_inject; auto.
    destr_pair_if; auto.
    apply Val.mul_inject; auto.
  - destruct p,p0. repeat apply Val.add_inject; auto.
    destr_pair_if; auto.
    apply Val.mul_inject; auto.
    apply inject_symbol_address. auto.
  - repeat apply Val.add_inject; auto.
  - destruct p. apply Val.add_inject; auto. 
    inject_match. apply inject_symbol_address; auto.
    destr_valinj_left H1; inv H1; auto.
    destr_pair_if. auto.
    eapply Val.inject_ptr; eauto.
    repeat unfold Ptrofs.of_int. 
    repeat rewrite Int.unsigned_zero. 
    repeat rewrite Ptrofs.add_zero. auto.
  - destruct p.
    inject_match.
    apply Val.add_inject; auto.
    destr_pair_if; auto.
    apply Val.mul_inject; auto.
    destr_valinj_left H1; inv H1; auto.
    destr_pair_if. auto.
    eapply Val.inject_ptr; eauto.
    repeat unfold Ptrofs.of_int. 
    repeat rewrite Int.unsigned_zero. 
    repeat rewrite Ptrofs.add_zero. auto.
  - destruct p,p0.
    inject_match.
    apply Val.add_inject; auto.
    destr_pair_if; auto.
    apply Val.mul_inject; auto.
    apply inject_symbol_address; auto.
    destr_valinj_left H1; inv H1; auto.
    destr_pair_if. auto.
    eapply Val.inject_ptr; eauto.
    repeat unfold Ptrofs.of_int. 
    repeat rewrite Int.unsigned_zero. 
    repeat rewrite Ptrofs.add_zero. auto.
  - repeat apply Val.add_inject; auto.
  - destruct p. 
    inject_match. inject_match.
    apply inject_symbol_address; auto.
    destr_valinj_left H1; inv H1; auto.
    destr_pair_if. auto.
    eapply Val.inject_ptr; eauto.
    repeat unfold Ptrofs.of_int. 
    repeat rewrite Int.unsigned_zero. 
    repeat rewrite Ptrofs.add_zero. auto.
    destr_valinj_left H1; inv H1; auto.
    destr_pair_if. auto.
    eapply Val.inject_ptr; eauto.
    repeat unfold Ptrofs.of_int. 
    repeat rewrite Int.unsigned_zero. 
    repeat rewrite Ptrofs.add_zero. auto.
Qed.    

Lemma eval_addrmode64_inject: forall j a rs1 rs2,
    match_inj j ->
    regset_inject j rs1 rs2 ->
    Val.inject j (Asm.eval_addrmode64 ge a rs1) (eval_addrmode64 tge a rs2).
Proof.
  intros. unfold Asm.eval_addrmode32, eval_addrmode32.
  destruct a. 
  destruct base, ofs, const; simpl in *.
  - destruct p. repeat apply Val.addl_inject; auto.
    destr_pair_if; auto.
    apply Val.mull_inject; auto.
  - destruct p,p0. repeat apply Val.addl_inject; auto.
    destr_pair_if; auto.
    apply Val.mull_inject; auto.
    apply inject_symbol_address. auto.
  - repeat apply Val.addl_inject; auto.
  - destruct p. apply Val.addl_inject; auto. 
    inject_match. apply inject_symbol_address; auto.
    destr_valinj_left H1; inv H1; auto.
    (* destr_pair_if; auto. *)
    (* eapply Val.inject_ptr; eauto.  *)
    (* repeat rewrite Ptrofs.add_assoc.  *)
    (* rewrite (Ptrofs.add_commut (Ptrofs.repr delta) (Ptrofs.of_int64 Int64.zero)). auto. *)
  - destruct p. 
    inject_match.
    apply Val.addl_inject; auto.
    destr_pair_if; auto. 
    apply Val.mull_inject; auto.
    destr_valinj_left H1; inv H1; auto.
    (* destr_pair_if; auto. *)
    (* eapply Val.inject_ptr; eauto.  *)
    (* repeat rewrite Ptrofs.add_assoc.  *)
    (* rewrite (Ptrofs.add_commut (Ptrofs.repr delta) (Ptrofs.of_int64 Int64.zero)). auto. *)
  - destruct p,p0.
    inject_match.
    apply Val.addl_inject; auto.
    destr_pair_if; auto. 
    apply Val.mull_inject; auto.
    apply inject_symbol_address; auto.
    destr_valinj_left H1; inv H1; auto.
    (* destr_pair_if; auto. *)
    (* eapply Val.inject_ptr; eauto.  *)
    (* repeat rewrite Ptrofs.add_assoc.  *)
    (* rewrite (Ptrofs.add_commut (Ptrofs.repr delta) (Ptrofs.of_int64 Int64.zero)). auto. *)
  - repeat apply Val.addl_inject; auto.
  - destruct p. inject_match. inject_match.
    apply inject_symbol_address; auto.
    destr_valinj_left H1; inv H1; auto.
    destr_valinj_left H1; inv H1; auto.
    (* eapply Val.inject_ptr; eauto.  *)
    (* repeat rewrite Ptrofs.add_assoc.  *)
    (* rewrite (Ptrofs.add_commut (Ptrofs.repr delta) (Ptrofs.of_int64 Int64.zero)). auto. *)    
Qed.

Lemma eval_addrmode_inject: forall j a rs1 rs2,
    match_inj j ->
    regset_inject j rs1 rs2 ->
    Val.inject j (Asm.eval_addrmode ge a rs1) (eval_addrmode tge a rs2).
Proof.
  intros. unfold Asm.eval_addrmode, eval_addrmode. destruct Archi.ptr64.
  + eapply eval_addrmode64_inject; eauto.
  + eapply eval_addrmode32_inject; eauto.
Qed.


Lemma exec_load_step: forall j rs1 rs2 m1 m2 rs1' m1' sz chunk rd a
                          (MINJ: Mem.inject j (def_frame_inj m1) m1 m2)
                          (MATCHINJ: match_inj j)
                          (RSINJ: regset_inject j rs1 rs2)
                          (GBVALID: glob_block_valid m1), 
    Asm.exec_load ge chunk m1 a rs1 rd sz = Next rs1' m1' ->
    exists rs2' m2',
      exec_load tge chunk m2 a rs2 rd sz = Next rs2' m2' /\
      match_states (State rs1' m1') (State rs2' m2').
Proof.
  intros. unfold Asm.exec_load in *.
  exploit eval_addrmode_inject; eauto. intro EMODINJ.
  destruct (Mem.loadv chunk m1 (Asm.eval_addrmode ge a rs1)) eqn:MLOAD; try congruence.
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

Lemma exec_store_step: forall j rs1 rs2 m1 m2 rs1' m1' sz chunk r a dregs
                         (MINJ: Mem.inject j (def_frame_inj m1) m1 m2)
                         (MATCHINJ: match_inj j)
                         (RSINJ: regset_inject j rs1 rs2)
                         (GBVALID: glob_block_valid m1),
    Asm.exec_store ge chunk m1 a rs1 r dregs sz = Next rs1' m1' ->
    exists rs2' m2',
      exec_store tge chunk m2 a rs2 r dregs sz = Next rs2' m2' /\
      match_states (State rs1' m1') (State rs2' m2').
Proof.
  intros. unfold Asm.exec_store in *.
  exploit eval_addrmode_inject; eauto. intro EMODINJ.
  destruct (Mem.storev chunk m1 (Asm.eval_addrmode ge a rs1) (rs1 r)) eqn:MSTORE; try congruence.
  exploit Mem.storev_mapped_inject; eauto. intros (m2' & MSTOREV & MINJ').
  eexists. eexists. split.
  - unfold exec_store. rewrite MSTOREV. auto.
  - inv H. eapply match_states_intro; eauto.
    erewrite <- storev_pres_def_frame_inj; eauto.
    apply nextinstr_pres_inject. repeat apply undef_regs_pres_inject. auto.
    eapply storev_pres_glob_block_valid; eauto.
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

Lemma eval_testcond_inject: forall j c rs1 rs2,
    regset_inject j rs1 rs2 ->
    Val.opt_lessdef (Asm.eval_testcond c rs1) (Asm.eval_testcond c rs2).
Proof.
  intros. destruct c; simpl; try solve_opt_lessdef.
Qed.

Hint Resolve nextinstr_nf_pres_inject nextinstr_pres_inject regset_inject_expand
  regset_inject_expand_vundef_left undef_regs_pres_inject
  Val.zero_ext_inject Val.sign_ext_inject Val.longofintu_inject Val.longofint_inject
  Val.singleoffloat_inject Val.loword_inject Val.floatofsingle_inject Val.intoffloat_inject Val.maketotal_inject
  Val.intoffloat_inject Val.floatofint_inject Val.intofsingle_inject Val.singleofint_inject
  Val.longoffloat_inject Val.floatoflong_inject Val.longofsingle_inject Val.singleoflong_inject
  eval_addrmode32_inject eval_addrmode64_inject eval_addrmode_inject
  Val.neg_inject Val.negl_inject Val.add_inject Val.addl_inject
  Val.sub_inject Val.subl_inject Val.mul_inject Val.mull_inject Val.mulhs_inject Val.mulhu_inject
  Val.mullhs_inject Val.mullhu_inject Val.shr_inject Val.shrl_inject Val.or_inject Val.orl_inject
  Val.xor_inject Val.xorl_inject Val.and_inject Val.andl_inject Val.notl_inject
  Val.shl_inject Val.shll_inject Val.vzero_inject Val.notint_inject
  Val.shru_inject Val.shrlu_inject Val.ror_inject Val.rorl_inject
  compare_ints_inject compare_longs_inject compare_floats_inject compare_floats32_inject
  Val.addf_inject Val.subf_inject Val.mulf_inject Val.divf_inject Val.negf_inject Val.absf_inject
  Val.addfs_inject Val.subfs_inject Val.mulfs_inject Val.divfs_inject Val.negfs_inject Val.absfs_inject
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
  | [ |- Next _ _ = Next _ _ /\ match_states _ _ ] =>
    split; [reflexivity | econstructor; eauto; solve_match_states]
  | [ |- (exec_instr _ _ _ _ = Next _ _) /\ match_states _ _ ] =>
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
  | [ H: Val.opt_lessdef (Some true) (Asm.eval_testcond _ _) |- _ ] =>
    inv H; destr_eval_testcond
  | [ H: Val.opt_lessdef (Some false) (Asm.eval_testcond _ _) |- _ ] =>
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


Lemma goto_ofs_pres_mem : forall f l rs1 m1 rs1' m1',
    Asm.goto_ofs ge f l rs1 m1 = Next rs1' m1' -> m1 = m1'.
Proof.
  unfold Asm.goto_label. intros.
  unfold Asm.goto_ofs in H. 
  repeat destr_in H.
Qed.

Lemma goto_ofs_inject : forall rs1 rs2 f l j m1 m2 rs1' m1'
                            (RINJ: regset_inject j rs1 rs2),
    Asm.goto_ofs ge f l rs1 m1 = Next rs1' m1' ->
    exists rs2', goto_ofs f l rs2 m2 = Next rs2' m2 /\
            regset_inject j rs1' rs2'.
Proof.
  intros. unfold Asm.goto_ofs in H.
  destr_in H. destr_in H. inv H.
  unfold goto_ofs.
  generalize (RINJ PC). rewrite Heqv.
  intros NJ. inv NJ.
  eexists; split; eauto.
  apply regset_inject_expand; auto.
  eapply Val.inject_ptr; eauto.
  repeat rewrite Ptrofs.add_assoc.
  f_equal.
  rewrite Ptrofs.add_commut.
  repeat rewrite Ptrofs.add_assoc.
  auto.
Qed.

Lemma goto_ofs_inject' : forall l f j rs1 rs2 m1 m2 rs1' m1'
                                (RINJ: regset_inject j rs1 rs2),
    Asm.goto_ofs ge f l ((rs1 # RAX <- Vundef) # RDX <- Vundef) m1 = Next rs1' m1' ->
    exists rs2',
      goto_ofs f l ((rs2 # RAX <- Vundef) # RDX <- Vundef) m2 = Next rs2' m2 /\
      regset_inject j rs1' rs2'.
Proof.
  intros. 
  eapply goto_ofs_inject; eauto.
  repeat apply regset_inject_expand; auto.
Qed.

Lemma extcall_pres_glob_block_valid : forall ef ge vargs m1 t vres m2,
  external_call ef ge vargs m1 t vres m2 -> glob_block_valid m1 -> glob_block_valid m2.
Proof.
  unfold glob_block_valid in *. intros.
  eapply external_call_valid_block; eauto.
Qed.


(** The internal step preserves the invariant *)
Lemma exec_instr_step : forall j rs1 rs2 m1 m2 rs1' m1' i ofs f b
                        (MINJ: Mem.inject j (def_frame_inj m1) m1 m2)
                        (MATCHSMINJ: match_inj j)
                        (RSINJ: regset_inject j rs1 rs2)
                        (GBVALID: glob_block_valid m1),
    rs1 PC = Vptr b ofs ->
    Globalenvs.Genv.find_funct_ptr ge b = Some (Internal f) ->
    Asm.find_instr (Ptrofs.unsigned ofs) (Asm.fn_code f) = Some i ->
    RealAsm.exec_instr ge f i rs1 m1 = Next rs1' m1' ->
    exists rs2' m2',
      exec_instr tge i rs2 m2 = Next rs2' m2' /\
      match_states (State rs1' m1') (State rs2' m2').
Proof.
  intros.
  destruct i; inv H2; simpl in *; 
    try first [solve_store_load |
               solve_match_states].

  - (* Pmov_rs *)
    apply nextinstr_nf_pres_inject.
    apply regset_inject_expand; auto.
    inv MATCHSMINJ.
    unfold Globalenvs.Genv.symbol_address.
    destruct (Globalenvs.Genv.find_symbol ge id) eqn:FINDSYM; auto.
    exploit agree_inj_globs0; eauto.
    intros (b1 & ofs1 & GLBL & JB).
    erewrite Genv.find_sym_to_addr with (ofs:=ofs1); eauto.
    rewrite <- (Ptrofs.add_zero_l ofs1).
    eapply Val.inject_ptr; eauto.
    rewrite Ptrofs.repr_unsigned. auto.

  (* Divisions *)
  - destr_match_outcome. 
    generalize (RSINJ Asm.RDX). generalize (RSINJ Asm.RAX). generalize (RSINJ r1).
    rewrite EQ, EQ0, EQ1. inversion 1; subst. inversion 1; subst. inversion 1; subst.
    eexists; eexists. split. simpl. rewrite EQ2. auto.
    eapply match_states_intro; eauto with inject_db.

  - destr_match_outcome. 
    generalize (RSINJ Asm.RDX). generalize (RSINJ Asm.RAX). generalize (RSINJ r1).
    rewrite EQ, EQ0, EQ1. inversion 1; subst. inversion 1; subst. inversion 1; subst.
    eexists; eexists. split. simpl. rewrite EQ2. auto.
    eapply match_states_intro; eauto with inject_db.

  - destr_match_outcome. 
    generalize (RSINJ Asm.RDX). generalize (RSINJ Asm.RAX). generalize (RSINJ r1).
    rewrite EQ, EQ0, EQ1. inversion 1; subst. inversion 1; subst. inversion 1; subst.
    eexists; eexists. split. simpl. rewrite EQ2. auto.
    eapply match_states_intro; eauto with inject_db.

  - destr_match_outcome. 
    generalize (RSINJ Asm.RDX). generalize (RSINJ Asm.RAX). generalize (RSINJ r1).
    rewrite EQ, EQ0, EQ1. inversion 1; subst. inversion 1; subst. inversion 1; subst.
    eexists; eexists. split. simpl. rewrite EQ2. auto.
    eapply match_states_intro; eauto with inject_db.
     
  - (* Pcmov *)
    exploit (eval_testcond_inject j c rs1 rs2); eauto.
    intros. 
    destr_eval_testcond; try solve_match_states.
    destruct (Asm.eval_testcond c rs2) eqn:EQ'. destruct b0; solve_match_states.
    solve_match_states.

  - (* Pjmp_l *)
    assert (instr_valid (Pjmp_l l)) as NJ.
    { eapply instr_is_valid; eauto. }
    red in NJ. cbn in NJ. contradiction.

  - (* Pjmp *)
    repeat destr_in H4.
    destruct ros; simpl in *.
    + do 2 eexists; split; eauto.
      econstructor; eauto.
      apply regset_inject_expand; auto.
    + do 2 eexists; split; eauto.
      econstructor; eauto.
      apply regset_inject_expand; auto.
      inversion MATCHSMINJ.
      unfold Globalenvs.Genv.symbol_address. destr_match; auto.
      exploit (agree_inj_globs0 i b0); eauto.
      intros (b1 & ofs1 & LBLOFS & JB).
      erewrite Genv.find_sym_to_addr with (ofs:=ofs1); eauto.
      rewrite <- (Ptrofs.add_zero_l ofs1).
      eapply Val.inject_ptr; eauto.
      rewrite Ptrofs.repr_unsigned. auto.

  - (* Pjcc *)
    assert (instr_valid (Pjcc c l)) as NJ.
    { eapply instr_is_valid; eauto. }
    red in NJ. cbn in NJ. contradiction.
    
  - (* Pjcc2 *)
    assert (instr_valid (Pjcc2 c1 c2 l)) as NJ.
    { eapply instr_is_valid; eauto. }
    red in NJ. cbn in NJ. contradiction.

  - (* Pjmptbl *)
    assert (instr_valid (Pjmptbl r tbl)) as NJ.
    { eapply instr_is_valid; eauto. }
    red in NJ. cbn in NJ. contradiction.

  - (* Pcall *)    
    repeat destr_in H4.
    generalize (RSINJ PC).
    edestruct storev_mapped_inject' as (m2' & ST & MINJ'). apply MINJ. eauto.
    apply Val.offset_ptr_inject. eauto.
    apply Val.offset_ptr_inject. eauto.
    do 2 eexists; split; eauto. simpl.
    rewrite ST. eauto.
    econstructor; eauto.
    repeat apply regset_inject_expand; auto.
    apply Val.offset_ptr_inject. eauto.
    destruct ros; simpl; repeat apply regset_inject_expand; auto.
    exploit (inject_symbol_address j i Ptrofs.zero); eauto.
    apply Val.offset_ptr_inject. eauto.
    eapply storev_pres_glob_block_valid; eauto. 
 
  - (* Pret *)
    repeat destr_in H4. simpl.
    exploit Mem.loadv_inject; eauto. intros (v2 & LD & VI). rewrite LD.
    eexists _, _; split; eauto. econstructor; eauto.
    repeat apply regset_inject_expand; auto.
    apply Val.offset_ptr_inject. eauto.

  - (* Pallocframe *)
    assert (instr_valid (Pallocframe sz pubrange ofs_ra)) as NJ.
    { eapply instr_is_valid; eauto. }
    red in NJ. cbn in NJ. contradiction.

  - (* Pfreeframe *)
    assert (instr_valid (Pfreeframe sz ofs_ra)) as NJ.
    { eapply instr_is_valid; eauto. }
    red in NJ. cbn in NJ. contradiction.

  - (* Pload_parent_pointer *)
    assert (instr_valid (Pload_parent_pointer rd sz)) as NJ.
    { eapply instr_is_valid; eauto. }
    red in NJ. cbn in NJ. contradiction.
    
  - (* Pjmp_l_rel *)
    unfold Asm.goto_ofs in H4. 
    destruct (rs1 Asm.PC) eqn:PC1; inv H4. 
    destruct (Globalenvs.Genv.find_funct_ptr ge b0); inv H3.
    generalize (RSINJ PC). rewrite PC1.
    intros INJ. inv INJ. eauto.
    eexists; eexists. split. 
    unfold goto_ofs. 
    rewrite <- H4. eauto.
    eapply match_states_intro; eauto.
    apply regset_inject_expand; auto. 
    rewrite H in *. inv PC1. inv H.
    eapply Val.inject_ptr; eauto. 
    repeat rewrite Ptrofs.add_assoc. f_equal.
    match goal with
    | [ |- _ = Ptrofs.add _ (Ptrofs.add ?b ?c) ] =>
      rewrite (Ptrofs.add_commut b c)
    end.
    match goal with
    | [ |- _ = Ptrofs.add ?a ?b ] =>
      rewrite (Ptrofs.add_commut a b)
    end.
    repeat rewrite Ptrofs.add_assoc. f_equal.
    apply Ptrofs.add_commut.
    
  - (* Pjcc_rel *)
    exploit (eval_testcond_inject j c rs1 rs2); eauto.
    intros.
    destr_eval_testcond; try solve_match_states.
    exploit goto_ofs_pres_mem; eauto. intros. subst.
    generalize (goto_ofs_inject _ _ _ _ _ m1' m2 _ _ RSINJ H4).
    intros (rs2' & GOTO & RINJ').
    exists rs2', m2. split; auto.
    eapply match_states_intro; eauto.

  - (* Pjcc2_rel *)
    exploit (eval_testcond_inject j c1 rs1 rs2); eauto.
    exploit (eval_testcond_inject j c2 rs1 rs2); eauto.
    intros ELF1 ELF2.
    destr_eval_testcond; try solve_match_states.
    exploit goto_ofs_pres_mem; eauto. intros. subst.
    generalize (goto_ofs_inject _ _ _ _ _ m1' m2 _ _ RSINJ H4).
    intros (rs2' & GOTO & RINJ').
    exists rs2', m2. split; auto.
    eapply match_states_intro; eauto.

  - (* Pjmptbl_rel *)
    destruct (rs1 r) eqn:REQ; inv H4.
    destruct (list_nth_z tbl (Int.unsigned i)) eqn:LEQ; inv H3.
    assert (rs2 r = Vint i) by
        (generalize (RSINJ r); rewrite REQ; inversion 1; auto).
    exploit goto_ofs_pres_mem; eauto. intros. subst.
    generalize (goto_ofs_inject' _ _ _ _ _ m1' m2 _ _ RSINJ H4).
    intros (rs2' & GLBL & RSINJ').
    exists rs2', m2. rewrite H2. rewrite LEQ.
    split; auto.
    eapply match_states_intro; eauto.

Qed.


Theorem step_simulation:
  forall S1 t S2,
    RealAsm.step ge S1 t S2 ->
    forall S1' (MS: match_states S1 S1'),
    exists S2',
      step tge S1' t S2' /\
      match_states S2 S2'.
Proof.
  destruct 1; intros; inv MS.

  - (* Internal step *)
    unfold regset_inject in RSINJ. generalize (RSINJ Asm.PC). rewrite H. 
    inversion 1; subst.
    exploit (agree_inj_instrs j MATCHINJ b b2 f ofs delta i); eauto.
    intros FIND.
    exploit (exec_instr_step j rs rs'0 m m'0 rs' m' i); eauto.
    intros (rs2' & m2' & FEXEC & MS1).
    exists (State rs2' m2'). split; auto.
    eapply exec_step_internal; eauto.
    eapply (agree_inj_int_funct j MATCHINJ); eauto.
        
  - (* Builtin *)
    unfold regset_inject in RSINJ. generalize (RSINJ Asm.PC). rewrite H.
    inversion 1; subst.
    exploit (agree_inj_instrs j MATCHINJ b b2 f ofs delta (Asm.Pbuiltin ef args res)); auto.
    intros FIND.
    exploit (eval_builtin_args_inject j m m'0 rs rs'0 (rs Asm.RSP) (rs'0 Asm.RSP) args vargs); auto.
    intros (vargs' & EBARGS & ARGSINJ).
    assert (Globalenvs.Genv.to_senv ge = (Genv.genv_senv tge)) as SENVEQ. 
    { eapply transf_prog_pres_senv; eauto. }
    generalize (external_call_inject ge j vargs vargs' m m'0 m' vres t ef ARGSINJ MINJ H3).
    rewrite SENVEQ.
    intros (j' & vres2 & m2' & EXTCALL & RESINJ & MINJ' & INJINCR & INJSEP).
    set (rs' := nextinstr_nf (set_res res vres2 (undef_regs (map preg_of (Machregs.destroyed_by_builtin ef)) rs'0)) 
                             (Ptrofs.repr (instr_size (Pbuiltin ef args res)))).
    exploit (fun b ofs => exec_step_builtin tge b ofs
                                         ef args res rs'0  m'0 vargs' t vres2 rs' m2'); eauto. 
    eapply (agree_inj_int_funct j MATCHINJ); eauto.
    intros FSTEP. eexists; split; eauto.
    eapply match_states_intro with (j:=j'); eauto.
    (* Supposely the following propreties can proved by separation property of injections *)
    + eapply (inject_pres_match_sminj j); eauto.
    + subst rs'. intros. 
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
    exploit Mem.loadv_inject. apply MINJ. apply LOADRA. eauto. intros (v2 & LRA & VI).
    edestruct (extcall_arguments_inject) as (args2 & ARGSINJ & EXTCALLARGS); eauto.
    apply regset_inject_expand. eauto.
    apply Val.offset_ptr_inject. eauto.
    assert (Globalenvs.Genv.to_senv ge = (Genv.genv_senv tge)) as SENVEQ. 
    { eapply transf_prog_pres_senv; eauto. }
    exploit (external_call_inject ge j args args2 ); eauto.
    rewrite SENVEQ.
    
    intros (j' & res' & m2'' & EXTCALL & RESINJ & MINJ' & INJINCR & INJSEP).
    exploit (fun ofs => exec_step_external tge b2 ofs ef args2 res'); eauto.
    eapply agree_inj_ext_funct; eauto.
    + intro; subst. inv VI. congruence.
    + intros FSTEP. eexists. split. apply FSTEP.
      eapply match_states_intro with (j := j'); eauto.
      * eapply (inject_pres_match_sminj j); eauto.
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
        apply regset_inject_expand; auto. eapply val_inject_incr; eauto.
        apply Val.offset_ptr_inject; eauto.
      * eapply extcall_pres_glob_block_valid; eauto.
Qed.


(** ** Matching of the Final States*)
Lemma transf_final_states:
  forall st1 st2 r,
  match_states st1 st2 -> Asm.final_state st1 r -> final_state st2 r.
Proof.
  intros st1 st2 r MATCH FINAL.
  inv FINAL. inv MATCH. constructor. 
  - red in RSINJ. generalize (RSINJ PC). rewrite H. 
    unfold Vnullptr. destruct Archi.ptr64; inversion 1; auto.
  - red in RSINJ. generalize (RSINJ RAX). rewrite H0.
    inversion 1. auto.
Qed.


(** ** The Main Correctness Theorem *)
Lemma transf_program_correct:
  forward_simulation (RealAsm.semantics prog (Pregmap.init Vundef)) 
                     (semantics tprog (Pregmap.init Vundef)).
Proof.
  intros. apply forward_simulation_step with match_states.
  - simpl. intros. 
    unfold match_prog in TRANSF. unfold transf_program in TRANSF.
    repeat destr_in TRANSF. cbn.
    rewrite add_external_globals_pres_senv. cbn. auto.
  - simpl. intros s1 IS. 
    exploit transf_initial_states; eauto.
    intros.
    rewrite Pregmap.gi. auto.
  - simpl. intros s1 s2 r MS FS. eapply transf_final_states; eauto.
  - simpl. intros s1 t s1' STEP s2 MS. 
    edestruct step_simulation as (STEP' & MS'); eauto.
Qed.


End PRESERVATION.
