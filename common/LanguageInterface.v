Require Import String.
Require Import RelationClasses.
Require Import Coqlib.
Require Import AST.
Require Import Integers.
Require Import Floats.
Require Import Values.
Require Import Memory.
Require Import Globalenvs.
Require Import Events.
Require Import KLR.
Require Import CKLR.
Require Export Inject.
Require Export InjectFootprint.
Require Export Extends.
Require Export ExtendsFootprint.


(** * Semantic interface of languages *)

Structure language_interface :=
  mk_language_interface {
    query: Type;
    reply: Type;
    query_is_internal: Senv.t -> query -> bool;
  }.

(** ** Interface for C-like languages *)

Record c_query :=
  cq {
    cq_id: ident;
    cq_sg: signature;
    cq_args: list val;
    cq_mem: mem;
  }.

Canonical Structure li_c :=
  {|
    query := c_query;
    reply := val * mem;
    query_is_internal ge q := Senv.block_is_internal ge (Block.glob (cq_id q));
  |}.

(** ** Miscellaneous interfaces *)

Definition li_wp :=
  {|
    query := unit;
    reply := int;
    query_is_internal ge q := true;
  |}.

Definition li_empty :=
  {|
    query := Empty_set;
    reply := Empty_set;
    query_is_internal ge q := true;
  |}.

(** * Calling conventions *)

(** ** Definition *)

Record callconv T1 T2 :=
  mk_callconv {
    ccworld : Type;
    match_senv: klr ccworld Senv.t Senv.t;
    match_query: klr ccworld (query T1) (query T2);
    match_reply: klr ccworld (reply T1) (reply T2);
  }.

Arguments ccworld {_ _}.
Arguments match_senv {_ _} _ _ _.
Arguments match_query {_ _} _ _ _.
Arguments match_reply {_ _} _ _ _.

Delimit Scope cc_scope with cc.
Bind Scope cc_scope with callconv.

(** ** Identity *)

Program Definition cc_id {T}: callconv T T :=
  {|
    ccworld := unit;
    match_senv w := eq;
    match_query w := eq;
    match_reply w := eq;
  |}.

Lemma match_cc_id {T} q:
  exists w,
    match_query (@cc_id T) w q q /\
    forall r1 r2,
      match_reply (@cc_id T) w r1 r2 ->
      r1 = r2.
Proof.
  exists tt.
  firstorder.
Qed.

Lemma match_query_cc_id {T} w q1 q2:
  match_query (@cc_id T) w q1 q2 ->
  q1 = q2.
Proof.
  firstorder.
Qed.

Lemma match_reply_cc_id {T} w r:
  match_reply (@cc_id T) w r r.
Proof.
  firstorder.
Qed.

Notation "1" := cc_id : cc_scope.

(** ** Composition *)

Section COMPOSE.
  Context {li1 li2 li3} (cc12: callconv li1 li2) (cc23: callconv li2 li3).

  Definition cc_compose :=
    {|
      ccworld := ccworld cc12 * ccworld cc23;
      match_senv w :=
        rel_compose (match_senv cc12 (fst w)) (match_senv cc23 (snd w));
      match_query w :=
        rel_compose (match_query cc12 (fst w)) (match_query cc23 (snd w));
      match_reply w :=
        rel_compose (match_reply cc12 (fst w)) (match_reply cc23 (snd w));
    |}.

  Lemma match_cc_compose w12 w23 q1 q2 q3:
    match_query cc12 w12 q1 q2 ->
    match_query cc23 w23 q2 q3 ->
    exists w,
      match_query cc_compose w q1 q3 /\
      forall r1 r3,
        match_reply cc_compose w r1 r3 ->
        exists r2,
          match_reply cc12 w12 r1 r2 /\
          match_reply cc23 w23 r2 r3.
  Proof.
    intros Hq12 Hq23.
    exists (w12, w23). simpl. intuition eauto.
  Qed.

  Lemma match_query_cc_compose (P: _ -> _ -> _ -> _ -> Prop):
    (forall w12 q1 q2, match_query cc12 w12 q1 q2 ->
     forall w23 q2' q3, match_query cc23 w23 q2' q3 ->
     q2' = q2 ->
     P w12 w23 q1 q3) ->
    (forall w q1 q3, match_query cc_compose w q1 q3 ->
     P (fst w) (snd w) q1 q3).
  Proof.
    intros H [w12 w23] q1 q3 (q2 & Hq12 & Hq23).
    eauto.
  Qed.

  Lemma match_reply_cc_compose w r1 r2 r3:
    match_reply cc12 (fst w) r1 r2 ->
    match_reply cc23 (snd w) r2 r3 ->
    match_reply cc_compose w r1 r3.
  Proof.
    intros H12 H23.
    destruct w as [w12 w23].
    simpl in *.
    eexists; eauto.
  Qed.
End COMPOSE.

Infix "@" := cc_compose (at level 30, right associativity) : cc_scope.

Ltac inv_compose_query :=
  let w := fresh "w" in
  let q1 := fresh "q1" in
  let q2 := fresh "q2" in
  let Hq := fresh "Hq" in
  intros w q1 q2 Hq;
  pattern (fst w), (snd w), q1, q2;
  revert w q1 q2 Hq;
  apply match_query_cc_compose.

(** * Common calling conventions *)

(** ** Generic convention for [li_c] *)

Inductive match_c_query (R: cklr) (w: world R): relation c_query :=
  match_c_query_intro id sg vargs1 vargs2 m1 m2:
    list_rel (Val.inject (mi R w)) vargs1 vargs2 ->
    match_mem R w m1 m2 ->
    match_c_query R w (cq id sg vargs1 m1) (cq id sg vargs2 m2).

Definition cc_c (R: cklr): callconv li_c li_c :=
  {|
    ccworld := world R;
    match_senv := symbols_inject @@ [mi R];
    match_query := match_c_query R;
    match_reply := <> Val.inject @@ [mi R] * match_mem R;
  |}.

(** ** Extension passes *)

Lemma val_inject_list_rel f:
  eqrel
    (Val.inject_list f)
    (list_rel (Val.inject f)).
Proof.
  split; induction 1; constructor; eauto.
Qed.

(** The following lemmas are used for incoming calls. *)

Lemma inv_query_ext (P: _ -> _ -> Prop):
  (forall id sg vargs1 vargs2 m1 m2,
    Val.lessdef_list vargs1 vargs2 ->
    Mem.extends m1 m2 ->
    P (cq id sg vargs1 m1) (cq id sg vargs2 m2)) ->
  (forall w q1 q2,
    match_query (cc_c ext) w q1 q2 ->
    P q1 q2).
Proof.
  intros H w q1 q2 Hq.
  destruct Hq as [id sg vargs1 vargs2 m1 m2 Hvargs Hm].
  apply val_inject_list_rel, val_inject_list_lessdef in Hvargs.
  eauto.
Qed.

Ltac inv_query_ext :=
  let w := fresh "w" in
  let q1 := fresh "q1" in
  let q2 := fresh "q2" in
  let Hq := fresh "Hq" in
  intros w q1 q2 Hq;
  pattern q1, q2;
  revert w q1 q2 Hq;
  eapply inv_query_ext; eauto.

Lemma match_reply_ext w vres1 m1' vres2 m2':
  Val.lessdef vres1 vres2 ->
  Mem.extends m1' m2' ->
  match_reply (cc_c ext) w (vres1, m1') (vres2, m2').
Proof.
  destruct w.
  intros.
  apply val_inject_lessdef in H.
  exists tt; split; rauto.
Qed.

(** The following lemmas are used for outgoing calls. *)

Lemma match_cc_ext id sg vargs1 m1 vargs2 m2:
  Mem.extends m1 m2 ->
  Val.lessdef_list vargs1 vargs2 ->
  exists w,
    match_query (cc_c ext) w (cq id sg vargs1 m1) (cq id sg vargs2 m2) /\
    forall vres1 m1' vres2 m2',
      match_reply (cc_c ext) w (vres1, m1') (vres2, m2') ->
      Val.lessdef vres1 vres2 /\
      Mem.extends m1' m2'.
Proof.
  intros Hm Hvargs.
  exists tt. split.
  - constructor; simpl; eauto.
    apply val_inject_list_lessdef in Hvargs.
    induction Hvargs; constructor; eauto.
  - intros vres1 m1' vres2 m2' (w' & Hw' & Hvres & Hm'). simpl in *.
    split; auto.
    apply val_inject_lessdef; eauto.
Qed.

Lemma match_cc_extp id sg vargs1 m1 vargs2 m2:
  Mem.extends m1 m2 ->
  Val.lessdef_list vargs1 vargs2 ->
  exists w,
    match_query (cc_c extp) w (cq id sg vargs1 m1) (cq id sg vargs2 m2) /\
    forall vres1 m1' vres2 m2',
      match_reply (cc_c extp) w (vres1, m1') (vres2, m2') ->
      Val.lessdef vres1 vres2 /\
      Mem.extends m1' m2' /\
      Mem.unchanged_on (loc_out_of_bounds m1) m2 m2'.
Proof.
  intros Hm Hvargs.
  exists (extpw m1 m2). split.
  - constructor; simpl; eauto.
    apply val_inject_list_lessdef in Hvargs.
    induction Hvargs; constructor; eauto.
    constructor; eauto.
  - intros vres1 m1' vres2 m2' (w' & Hw' & Hvres & Hm'). cbn [fst snd] in *.
    inversion Hw' as [xm1 xm2 xm1' xm2' Hperm Hunch]; subst.
    inv Hm'. simpl in Hvres. red in Hvres.
    intuition eauto.
    apply val_inject_lessdef; eauto.
Qed.

(** ** Injection passes *)

(** Incoming calls follow the [cc_c inj] calling convention. *)

Lemma inv_query_inj (P: _ -> _ -> _ -> Prop):
  (forall f id sg vargs1 vargs2 m1 m2,
    Val.inject_list f vargs1 vargs2 ->
    Mem.inject f m1 m2 ->
    inject_incr (Mem.flat_inj Block.init) f ->
    (forall b1 b2 delta,
        f b1 = Some (b2, delta) ->
        Block.lt b2 Block.init ->
        Block.lt b1 Block.init) ->
    P f (cq id sg vargs1 m1) (cq id sg vargs2 m2)) ->
  (forall w q1 q2,
    match_query (cc_c inj) w q1 q2 ->
    P w q1 q2).
Proof.
  intros H w q1 q2 Hq.
  destruct Hq as [id sg vargs1 vargs2 m1 m2 Hvargs Hm].
  apply val_inject_list_rel in Hvargs.
  destruct Hm as (Hm & Hincr & Himg).
  apply H; eauto.
Qed.

Ltac inv_query_inj :=
  let w := fresh "w" in
  let q1 := fresh "q1" in
  let q2 := fresh "q2" in
  let Hq := fresh "Hq" in
  intros w q1 q2 Hq;
  pattern w, q1, q2;
  revert w q1 q2 Hq;
  eapply inv_query_inj; eauto.

Lemma match_reply_inj f f' vres1 m1' vres2 m2':
  Val.inject f' vres1 vres2 ->
  Mem.inject f' m1' m2' ->
  inject_incr f f' ->
  CKLR.meminj_wf f' ->
  match_reply (cc_c inj) f (vres1, m1') (vres2, m2').
Proof.
  intros Hvres Hm' Hff' Hf'.
  exists f'; cbn; intuition auto.
  rauto.
Qed.

(** Outgoing calls follow [cc_c injp]. *)

Lemma match_cc_inject id sg f vargs1 m1 vargs2 m2:
  Val.inject_list f vargs1 vargs2 ->
  Mem.inject f m1 m2 ->
  meminj_wf f ->
  exists w,
    match_query (cc_c injp) w (cq id sg vargs1 m1) (cq id sg vargs2 m2) /\
    forall vres1 m1' vres2 m2',
      match_reply (cc_c injp) w (vres1, m1') (vres2, m2') ->
      exists f',
        Val.inject f' vres1 vres2 /\
        Mem.inject f' m1' m2' /\
        Mem.unchanged_on (loc_unmapped f) m1 m1' /\
        Mem.unchanged_on (loc_out_of_reach f m1) m2 m2' /\
        inject_incr f f' /\
        inject_separated f f' m1 m2 /\
        forall b ofs p,
          Mem.valid_block m1 b ->
          Mem.perm m1' b ofs Max p ->
          Mem.perm m1 b ofs Max p.
Proof.
  intros Hvargs Hm.
  exists (injpw f m1 m2). simpl. split.
  - constructor; simpl; eauto.
    induction Hvargs; constructor; eauto.
  - intros vres1 m1' vres2 m2' (w' & Hw' & Hvres & Hm'). simpl in *.
    inv Hw'. inv Hm'.
    exists f'. intuition eauto.
    destruct (f b) as [[b' delta] | ] eqn:Hb.
    + eauto.
    + eapply Mem.unchanged_on_perm; eauto.
Qed.

(** For passes which use a triangular injection diagram for their
  incoming calls, the following lemma may be useful for proving the
  [block_inject] premise of [match_cc_inject]. *)

Lemma funct_ptr_flat_inject {F V} (ge: Genv.t F V) f fd b thr:
  Genv.find_funct_ptr ge b = Some fd ->
  Block.le Block.init thr ->
  inject_incr (Mem.flat_inj thr) f ->
  block_inject f b b.
Proof.
  clear.
  intros Hfd Hthr Hf.
  apply Genv.find_funct_ptr_iff in Hfd.
  apply Genv.genv_defs_range in Hfd.
  exists 0. apply Hf.
  unfold Mem.flat_inj.
  destruct Block.lt_dec; eauto.
  elim n. blomega.
Qed.