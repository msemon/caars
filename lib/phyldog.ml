(*
# File: Phyldog.ml
# Created by: Carine Rey
# Created on: March 2016
#
#
# Copyright 2016 Carine Rey
# This software is a computer program whose purpose is to assembly
# sequences from RNA-Seq data (paired-end or single-end) using one or
# more reference homologous sequences.
# This software is governed by the CeCILL license under French law and
# abiding by the rules of distribution of free software.  You can  use,
# modify and/ or redistribute the software under the terms of the CeCILL
# license as circulated by CEA, CNRS and INRIA at the following URL
# "http://www.cecill.info".
# As a counterpart to the access to the source code and  rights to copy,
# modify and redistribute granted by the license, users are provided only
# with a limited warranty  and the software's author,  the holder of the
# economic rights,  and the successive licensors  have only  limited
# liability.
# In this respect, the user's attention is drawn to the risks associated
# with loading,  using,  modifying and/or developing or reproducing the
# software by the user in light of its specific status of free software,
# that may mean  that it is complicated to manipulate,  and  that  also
# therefore means  that it is reserved for developers  and  experienced
# professionals having in-depth computer knowledge. Users are therefore
# encouraged to load and test the software's suitability as regards their
# requirements in conditions enabling the security of their systems and/or
# data to be ensured and,  more generally, to use and operate it in the
# same conditions as regards security.
# The fact that you are presently reading this means that you have had
# knowledge of the CeCILL license and that you accept its terms.
*)

open Core.Std
open Bistro.Std
open Bistro.EDSL
open Bistro_bioinfo.Std

type phyldog_configuration = [`phyldog_configuration] directory

type phylotree

let phyldog_by_fam
    ?(descr="")
    ?datatype
    ?dataformat
    ?sptreefile
    ?topospecies
    ?dlopt
    ?max_gap
    ?equgenomes
    ?topogene
    ?timelimit
    ?(memory = 1)
    ~threads
    ~link
    ~tree
    (ali :fasta workflow)
    : phylotree directory workflow =

    let config_dir = dest // "Configuration" in
    let results_species = dest // "Species_tree/" in
    let results_genes = dest // "Gene_trees/" in
    workflow ~descr:("phyldog_by_fam" ^ descr) ~version:4 ~np:threads ~mem:(1024 * memory) [
    mkdir_p config_dir;
    mkdir_p results_species;
    mkdir_p results_genes;
    mkdir_p (dest // "tmp_phyldog");
    cd (dest // "tmp_phyldog");
    (* Preparing phyldog configuration files*)
    cmd "PhyldogPrepDataByFam.py" [
              option (opt "-datatype" string) datatype ;
              option (opt "-dataformat" string) dataformat ;
              option (opt "-species_tree_file" string) sptreefile ;
              option (flag string "-topospecies") topospecies ;
              option (opt "-dlopt" string) dlopt ;
              option (opt "-max_gap" float) max_gap ;
              option (opt "-timelimit" int) timelimit ;
              option (flag string "-equgenomes") equgenomes ;
              option (flag string "-topogene") topogene ;
              opt "-link" dep link;
              opt "-seq" dep ali;
              opt "-starting_tree" dep tree;
              opt "-species_tree_resdir" ident results_species;
              opt "-gene_trees_resdir" ident results_genes;
              opt "-optdir" seq [ ident config_dir ] ;
              ];
    let script = [%bistro {|
    nb_species=`wc -l < {{ident (config_dir // "listSpecies.txt")}} `
    filename=`basename {{ dep tree }}`
    family=${filename%.*}
    touch {{ ident results_species}}"$family".orthologs.txt
    touch {{ ident results_species}}"$family".events.txt
    if [ $nb_species -gt 2 ]
    then
     mpirun -np {{ ident np  }} -mca btl sm,self phyldog param={{ident (config_dir // "GeneralOptions.txt")}}
     cut -f 2 {{ ident results_species}}orthologs.txt > {{ ident results_species}}"$family".orthologs.txt
     cut -f 1,3- -d "," {{ ident results_species}}events.txt > {{ ident results_species}}"$family".events.txt
    else
     nw2nhx.py {{ dep tree }} >  {{ ident results_genes }}"$family".ReconciledTree
    fi
    |} ]
    in
    cmd "sh" [ file_dump script ];
    (*
    (* Run phyldog *)
    cmd "mpirun" [
            opt "-np" ident np ;
            string "phyldog";
            seq ~sep:"=" [string "param";  ident (config_dir // "GeneralOptions.txt") ];
            ];
    *)
    ]

let phyldog
    ?datatype
    ?dataformat
    ?sptreefile
    ?topospecies
    ?dlopt
    ?equgenomes
    ?topogene
    ?timelimit
    ?(memory = 1)
    ~threads
    ~linkdir
    ~treedir
    (seqdir :fasta directory workflow)
    : phylotree directory workflow =

    let config_dir = dest // "Configuration" in
    let results_species = dest // "Species_tree/" in
    let results_genes = dest // "Gene_trees/" in
    workflow ~version:5 ~np:threads ~mem:(1024 * memory) [
    mkdir_p config_dir;
    mkdir_p results_species;
    mkdir_p results_genes;
    mkdir_p (dest // "tmp_phyldog");
    cd (dest // "tmp_phyldog");
    (* Preparing phyldog configuration files*)
    cmd "PhyldogPrepData.py" [
              option (opt "-datatype" string) datatype ;
              option (opt "-dataformat" string) dataformat ;
              option (opt "-species_tree_file" string) sptreefile ;
              option (flag string "-topospecies") topospecies ;
              option (opt "-dlopt" string) dlopt ;
              option (opt "-timelimit" int) timelimit ;
              option (flag string "-equgenomes") equgenomes ;
              option (flag string "-topogene") topogene ;
              opt "-linkdir" dep linkdir;
              opt "-seqdir" dep seqdir;
              opt "-starting_tree_dir" dep treedir;
              opt "-species_tree_resdir" ident results_species;
              opt "-gene_trees_resdir" ident results_genes;
              opt "-optdir" seq [ ident config_dir ] ;
              ];
    (* Run phyldog *)
    cmd "mpirun" [
            opt "-np" ident np ;
            string "phyldog";
            seq ~sep:"=" [string "param";  ident (config_dir // "GeneralOptions.txt") ];
            ];
    ]
