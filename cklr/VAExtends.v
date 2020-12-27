Require Import Axioms.
Require Import Events.
Require Import LanguageInterface.
Require Import CallconvAlgebra.
Require Import CKLR.
Require Import Extends.
Require Import ValueAnalysis.
Require Import ValueDomain.
Unset Program Cases.


(** * Preliminaries *)

Instance inj_of_bc_id bc:
  Related (inj_of_bc bc) inject_id inject_incr.
Proof.
  unfold inj_of_bc, inject_id.
  intros b1 b2 delta Hb. destruct (bc b1); congruence.
Qed.


(** * Definition *)

(** ** Worlds *)

(** As in the case of [injp], we store a lot of properties in the world itself. *)

Record vaext_wf se bc m :=
  {
    vaext_genv_match : genv_match bc se;
    vaext_mmatch : mmatch bc m mtop;
    vaext_romatch : romatch_all se bc m;
    vaext_nostack : bc_nostack bc;
  }.

Record vaext_world :=
  vaextw {
    vaext_se : Genv.symtbl;
    vaext_bc : block_classification;
    vaext_m1 : mem;
    vaext_prop : vaext_wf vaext_se vaext_bc vaext_m1;
  }.

Record vaext_incr (w w' : vaext_world) : Prop :=
  {
    vaext_incr_se :
      vaext_se w = vaext_se w';
    vaext_incr_bc b :
      Plt b (Mem.nextblock (vaext_m1 w)) ->
      vaext_bc w' b = vaext_bc w b;
    vaext_incr_nextblock :
      Pos.le (Mem.nextblock (vaext_m1 w)) (Mem.nextblock (vaext_m1 w'));
    vaext_incr_load b ofs n bytes :
      Plt b (Mem.nextblock (vaext_m1 w)) ->
      vaext_bc w b = BCinvalid ->
      n >= 0 ->
      Mem.loadbytes (vaext_m1 w') b ofs n = Some bytes ->
      Mem.loadbytes (vaext_m1 w) b ofs n = Some bytes;
  }.

Instance vaext_incr_preo:
  PreOrder vaext_incr.
Proof.
  split.
  - intros [se bc m H]. constructor; cbn; auto using Pos.le_refl.
  - intros [se1 bc1 m1 H1] [se2 bc2 m2 H2] [se3 bc3 m3 H3].
    intros [Hse12 Hbc12 Hnb12 Hld12] [Hse23 Hbc23 Hnb23 Hld23]; cbn in *.
    constructor; cbn in *; try (etransitivity; eauto).
    + rewrite Hbc23; auto. xomega.
    + eapply Hld12; auto. eapply Hld23; auto.
      * xomega.
      * rewrite Hbc12; auto.
Qed.

(** ** Relations *)

Inductive vaext_stbls : klr vaext_world Genv.symtbl Genv.symtbl :=
  vaext_stbls_intro se bc m H :
    genv_match bc se ->
    vaext_stbls (vaextw se bc m H) se se.

Inductive vaext_mem : klr vaext_world mem mem :=
  vaext_mem_intro se bc m1 m2 H :
    Mem.extends m1 m2 ->
    vaext_mem (vaextw se bc m1 H) m1 m2.

(** ** CKLR *)

Program Definition vaext : cklr :=
  {|
    world := vaext_world;
    wacc := vaext_incr;
    mi w := inj_of_bc (vaext_bc w);
    match_stbls := vaext_stbls;
    match_mem := vaext_mem;
  |}.

Instance inj_of_bc_incr:
  Monotonic (inj_of_bc) (bc_incr ++> inject_incr).
Proof.
  intros bc1 bc2 Hbc b1 b2 delta Hb. unfold inj_of_bc in *.
  destruct (bc1 b1) eqn:H; try rewrite Hbc, H; congruence.
Qed.

Next Obligation.
  intros [se1 bc1 m1 H1] [se2 bc2 m2 H2] [Hse Hbc Hnb Hld]; cbn in *.
  rstep. intros b Hb. apply Hbc.
  eapply mmatch_below; eauto.
  eapply vaext_mmatch; eauto.
Qed.

Next Obligation.
  intros [se1 bc1 m1 H1] [se2 bc2 m2 H2] [Hse Hbc Hnb Hld]; cbn in *.
  inversion 1; clear H; subst. constructor.
  eapply vaext_genv_match; eauto.
Qed.

Next Obligation.
  destruct 1; cbn.
  eapply inj_of_bc_preserves_globals; auto.
Qed.

Next Obligation.
  destruct H0. inv H.
  erewrite <- Mem.mext_next; eauto.
Qed.

(** Alloc *)

Program Definition alloc_bc (b : block) (bc : block_classification) :=
  {|
    bc_img x := if Pos.eqb x b then BCother else bc x;
  |}.
Next Obligation.
  destruct Pos.eqb; try discriminate.
  destruct Pos.eqb; try discriminate.
  eapply bc_stack; eauto.
Qed.
Next Obligation.
  destruct Pos.eqb; try discriminate.
  destruct Pos.eqb; try discriminate.
  eapply bc_glob; eauto.
Qed.

Lemma alloc_bc_glob bc m am x id :
  mmatch bc m am ->
  bc x = BCglob id <-> alloc_bc (Mem.nextblock m) bc x = BCglob id.
Proof.
  intros Hm. cbn.
  destruct Pos.eqb eqn:Hx; try reflexivity.
  apply Pos.eqb_eq in Hx; subst.
  split; try discriminate.
  intros Hb; exfalso.
  exploit mmatch_below; eauto. rewrite Hb; discriminate.
  xomega.
Qed.

Lemma alloc_bc_incr bc m am :
  mmatch bc m am ->
  bc_incr bc (alloc_bc (Mem.nextblock m) bc).
Proof.
  intros Hm x VALID. cbn.
  destruct Pos.eqb eqn:Hx; try reflexivity.
  apply Pos.eqb_eq in Hx; subst.
  exploit mmatch_below; eauto. xomega.
Qed.

Lemma alloc_mmatch m lo hi m' b bc am :
  bc_nostack bc ->
  mmatch bc m am ->
  Mem.alloc m lo hi = (m', b) ->
  mmatch (alloc_bc b bc) m' am.
Proof.
  intros Hbc Hm Hm'.
  rewrite (Mem.alloc_result m lo hi m' b); auto.
  split.
  - cbn. intros x Hx.
    destruct Pos.eqb; try discriminate.
    eelim Hbc; eauto.
  - intros id ab x Hx Hab.
    eapply alloc_bc_glob in Hx; eauto.
    eapply bmatch_incr; eauto using alloc_bc_incr.
    eapply bmatch_ext; eauto using mmatch_glob.
    intros. erewrite <- Mem.loadbytes_alloc_unchanged; eauto.
    eapply mmatch_below; eauto. congruence.
  - intros x NOSTK VALID.
    eapply smatch_incr; eauto using alloc_bc_incr.
    cbn in *. destruct Pos.eqb eqn:Hx.
    + apply Pos.eqb_eq in Hx; subst.
      split; intros.
      * erewrite <- Mem.alloc_result in H; eauto.
        erewrite (Mem.load_alloc_same m lo hi m' b Hm' chunk ofs v); eauto.
        constructor.
      * erewrite <- Mem.alloc_result in H; eauto.
        exploit (Mem.loadbytes_alloc_same m lo hi m' b Hm'); eauto.
        -- left. reflexivity.
        -- congruence.
    + eapply smatch_ext; eauto using mmatch_nonstack. intros.
      erewrite <- Mem.loadbytes_alloc_unchanged; eauto.
      eapply mmatch_below; eauto.
  - intros x VALID.
    eapply smatch_incr; eauto using alloc_bc_incr.
    cbn in *. destruct Pos.eqb eqn:Hx.
    + apply Pos.eqb_eq in Hx; subst.
      split; intros.
      * erewrite <- Mem.alloc_result in H; eauto.
        erewrite (Mem.load_alloc_same m lo hi m' b Hm' chunk ofs v); eauto.
        constructor.
      * erewrite <- Mem.alloc_result in H; eauto.
        exploit (Mem.loadbytes_alloc_same m lo hi m' b Hm'); eauto.
        -- left. reflexivity.
        -- congruence.
    + eapply smatch_ext; eauto using mmatch_top. intros.
      erewrite <- Mem.loadbytes_alloc_unchanged; eauto.
      eapply mmatch_below; eauto.
  - intros x Hx. cbn in Hx.
    rewrite (Mem.nextblock_alloc m lo hi m' b); auto.
    destruct Pos.eqb eqn:Hxeq.
    + apply Pos.eqb_eq in Hxeq. xomega.
    + etransitivity.
      * eapply mmatch_below; eauto.
      * xomega.
Qed. 

Next Obligation.
  destruct 1. intros lo hi.
  destruct (Mem.alloc m1) as [m1' b] eqn:Hm1'.
  edestruct Mem.alloc_extends as (m2' & Hm2' & Hm'); eauto.
  reflexivity. reflexivity.
  assert (vaext_wf se (alloc_bc b bc) m1').
  {
    destruct H. split.
    - rewrite (Mem.alloc_result m1 lo hi m1' b); auto.
      eapply genv_match_exten; eauto.
      + eauto using alloc_bc_glob.
      + intros. erewrite alloc_bc_incr; eauto. congruence.
    - eapply alloc_mmatch; eauto.
    - rewrite (Mem.alloc_result m1 lo hi m1' b); auto.
      intros cu Hcu.
      eapply romatch_exten; eauto using romatch_alloc, mmatch_below.
      intros. symmetry. eapply alloc_bc_glob; eauto.
    - intros x. cbn. destruct Pos.eqb; eauto. discriminate.
  }
  exists (vaextw se (alloc_bc b bc) m1' H1). split.
  - constructor; cbn; auto.
    + rewrite (Mem.alloc_result m1 lo hi m1' b); auto.
      intros. destruct Pos.eqb eqn:Heq; auto.
      apply Pos.eqb_eq in Heq. xomega.
    + rewrite (Mem.nextblock_alloc m1 lo hi m1' b); auto.
      xomega.
    + intros.
      erewrite <- Mem.loadbytes_alloc_unchanged; eauto.
  - rewrite Hm2'. repeat rstep.
    + constructor.
      edestruct (Mem.alloc_extends m1 m2 lo hi b m1' lo hi); eauto; xomega.
    + red. cbn. unfold inj_of_bc. cbn.
      rewrite Pos.eqb_refl. reflexivity.
Qed.

Next Obligation.
  intros w m1 m2 Hm p p' Hptr. destruct Hm.
  assert (p = p') as Hp by (apply coreflexivity; rauto). destruct Hp.
  destruct p as [[b lo] hi]. cbn in *.
  destruct (Mem.free m1) as [m1' | ] eqn:Hm1'; [ | constructor].
  edestruct Mem.free_parallel_extends as (m2' & Hm2' & Hm'); eauto.
  rewrite Hm2'. constructor.
  assert (H' : vaext_wf se bc m1').
  {
    destruct H.
    constructor; auto.
    + eapply mmatch_free; eauto.
    + intros cu Hcu. eapply romatch_free; eauto.
  }
  exists (vaextw _ _ _ H'). split. 
  - constructor; cbn; auto.
    + rewrite (Mem.nextblock_free m1 b lo hi m1'); eauto. reflexivity.
    + intros. red in Hptr; cbn in Hptr.
      destruct (Pos.eq_dec b0 b); subst.
      * inv Hptr. inv H6. unfold inj_of_bc in H7. rewrite H2 in H7. discriminate.
      * eapply Mem.loadbytes_free_2; eauto.
  - constructor; auto.
Qed.

Lemma vaext_wf_inj se bc m:
  vaext_wf se bc m ->
  Mem.inject (inj_of_bc bc) m m.
Proof.
  destruct 1.
  eapply mmatch_inj; eauto.
  eapply mmatch_below; eauto.
Qed.


Next Obligation.
  intros _ chunk _ _ [se bc m1 m2 H Hm] p p' Hp.
  assert (p = p') as Hp' by (eapply coreflexivity; rauto). destruct Hp'.
  destruct p as [b ofs]. cbn.
  destruct (Mem.load chunk m1) as [v1 | ] eqn:Hv1; [ | constructor].
  exploit vaext_wf_inj; eauto. intros Hm1.
  inv Hp. cbn in *.
  edestruct Mem.load_inject; eauto.
Admitted.

Next Obligation.
Admitted.

Next Obligation.
Admitted.

Next Obligation.
Admitted.

Next Obligation.
Admitted.

Next Obligation.
Admitted.

Next Obligation.
Admitted.

Next Obligation.
Admitted.

Next Obligation.
Admitted.

Next Obligation.
Admitted.

Next Obligation.
Admitted.




(** * Other properties *)

(** ** Connection with [vamatch] *)

Require Import Invariant.

Lemma vmatch_list_inj_top bc vargs1 vargs2 v:
  Val.inject_list (inj_of_bc bc) vargs1 vargs2 ->
  In v vargs1 ->
  vmatch bc v Vtop.
Proof.
  induction 1; destruct 1; eauto.
  subst. eapply vmatch_inj_top; eauto.
Qed.

Lemma val_inject_lessdef_list_compose f v1 v2 v3:
  Val.inject_list f v1 v2 ->
  Val.lessdef_list v2 v3 ->
  Val.inject_list f v1 v3.
Proof.
  intros Hv12. revert v3.
  induction Hv12; inversion 1; subst; constructor; eauto.
  eapply Mem.val_inject_lessdef_compose; eauto.
Qed.

Lemma vaext_va_ext:
  cceqv (cc_c vaext) (vamatch @ cc_c ext).
Proof.
  split.
  - intros w se1 se2 q1 q2 Hse Hq.
    destruct Hq. destruct Hse. cbn in * |- . inv H1. destruct H12.
    exists (se, vaw se bc m1, tt). cbn. repeat apply conj; auto using rel_inv_intro.
    + eexists; split; constructor; cbn; auto.
      * constructor; eauto using vmatch_list_inj_top.
      * eapply val_inject_incr. apply inj_of_bc_id. eauto.
      * eapply val_inject_list_incr. apply inj_of_bc_id. eauto.
    + intros r1 r2 (ri & Hr1i & Hri2). destruct Hr1i, Hri2 as ([ ] & _ & ?).
      destruct H1. inv H5. cbn in *.
      assert (Hw' : vaext_wf se bc' m') by (constructor; auto).
      exists (vaextw se bc' m' Hw'). split.
      * constructor; auto.
      * constructor; cbn; auto.
        -- apply val_inject_id in H18. 
           eapply Mem.val_inject_lessdef_compose; eauto.
           eapply vmatch_inj; eauto.
        -- constructor; auto.
  - intros [[se1 w] [ ]] se se2 q1 q2 [Hse1i Hsei2] (qi & Hq1i & Hqi2).
    destruct Hse1i. destruct Hsei2. destruct Hqi2. inv Hq1i. cbn in * |- .
    destruct w as [xse bc xm]. cbn in * |- . inv H4.
    assert (Hw: vaext_wf se bc m1) by (constructor; auto).
    exists (vaextw _ _ _ Hw). cbn. repeat apply conj.
    + constructor; auto.
    + constructor; cbn; auto.
      * apply val_inject_id in H0.
        eapply Mem.val_inject_lessdef_compose; eauto.
        admit. (* need something in vamatch for vf *)
      * apply val_inject_list_lessdef in H1.
        eapply val_inject_lessdef_list_compose; eauto.
        clear - H10.
        induction vargs1; constructor; eauto.
        -- eapply vmatch_inj. eapply H10. cbn. auto.
        -- eapply IHvargs1. intros. eapply H10. cbn. auto.
      * constructor; auto.
    + intros r1 r2 ([se' bc' m1' Hwf] & Hw' & Hr). destruct Hw'; cbn in *. subst se'.
      inv Hr. inv H4. destruct Hwf. cbn in *.
      eexists. split.
      * constructor. econstructor; eauto.
        eapply vmatch_inj_top; eauto.
      * exists tt. split; constructor.
        -- eapply val_inject_incr. apply inj_of_bc_id. eauto.
        -- cbn. auto.
Admitted.
