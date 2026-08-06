/* -*- P4_16 -*- */
/* Consolidation feasibility test: TWO heterogeneous per-user pipelines
 * instantiated as separate Pipeline() instances inside one Switch().
 *   pipeA = user 0: L2 forward keyed on ethernet.ether_type (ethernet only)
 *   pipeB = user 1: IPv4 forward with TTL decrement (ethernet + ipv4)
 * Deliberately different headers / metadata / parsers / tables / actions.
 */
#include <core.p4>
#include <tna.p4>

const bit<16> ETHERTYPE_IPV4 = 0x0800;

/*==================== PIPELINE A : L2 forward on ethertype ====================*/
header a_ethernet_h { bit<48> dst_addr; bit<48> src_addr; bit<16> ether_type; }
struct a_ig_headers_t  { a_ethernet_h ethernet; }
struct a_ig_metadata_t { bit<16> class_id; }
struct a_eg_headers_t  { }
struct a_eg_metadata_t { }

parser A_IngressParser(packet_in pkt, out a_ig_headers_t hdr, out a_ig_metadata_t meta,
        out ingress_intrinsic_metadata_t ig_intr_md) {
    state start {
        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }
    state parse_ethernet { pkt.extract(hdr.ethernet); transition accept; }
}
control A_Ingress(inout a_ig_headers_t hdr, inout a_ig_metadata_t meta,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {
    action send(PortId_t port) { ig_tm_md.ucast_egress_port = port; }
    action drop() { ig_dprsr_md.drop_ctl = 1; }
    table l2_fwd {
        key = { hdr.ethernet.ether_type : exact; }
        actions = { send; drop; }
        default_action = drop();
        size = 1024;
    }
    apply { l2_fwd.apply(); }
}
control A_IngressDeparser(packet_out pkt, inout a_ig_headers_t hdr, in a_ig_metadata_t meta,
        in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md) {
    apply { pkt.emit(hdr); }
}
parser A_EgressParser(packet_in pkt, out a_eg_headers_t hdr, out a_eg_metadata_t meta,
        out egress_intrinsic_metadata_t eg_intr_md) {
    state start { pkt.extract(eg_intr_md); transition accept; }
}
control A_Egress(inout a_eg_headers_t hdr, inout a_eg_metadata_t meta,
        in egress_intrinsic_metadata_t eg_intr_md,
        in egress_intrinsic_metadata_from_parser_t eg_prsr_md,
        inout egress_intrinsic_metadata_for_deparser_t eg_dprsr_md,
        inout egress_intrinsic_metadata_for_output_port_t eg_oport_md) {
    apply { }
}
control A_EgressDeparser(packet_out pkt, inout a_eg_headers_t hdr, in a_eg_metadata_t meta,
        in egress_intrinsic_metadata_for_deparser_t eg_dprsr_md) {
    apply { pkt.emit(hdr); }
}

/*==================== PIPELINE B : IPv4 TTL-decrement forward ====================*/
header b_ethernet_h { bit<48> dst_addr; bit<48> src_addr; bit<16> ether_type; }
header b_ipv4_h {
    bit<4> version; bit<4> ihl; bit<8> diffserv; bit<16> total_len;
    bit<16> identification; bit<3> flags; bit<13> frag_offset;
    bit<8> ttl; bit<8> protocol; bit<16> hdr_checksum;
    bit<32> src_addr; bit<32> dst_addr;
}
struct b_ig_headers_t  { b_ethernet_h ethernet; b_ipv4_h ipv4; }
struct b_ig_metadata_t { bit<32> nexthop; }
struct b_eg_headers_t  { }
struct b_eg_metadata_t { }

parser B_IngressParser(packet_in pkt, out b_ig_headers_t hdr, out b_ig_metadata_t meta,
        out ingress_intrinsic_metadata_t ig_intr_md) {
    state start {
        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }
    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ETHERTYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }
    state parse_ipv4 { pkt.extract(hdr.ipv4); transition accept; }
}
control B_Ingress(inout b_ig_headers_t hdr, inout b_ig_metadata_t meta,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {
    action fwd(PortId_t port) {
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
        ig_tm_md.ucast_egress_port = port;
    }
    action drop() { ig_dprsr_md.drop_ctl = 1; }
    table ipv4_fwd {
        key = { hdr.ipv4.dst_addr : exact; }
        actions = { fwd; drop; }
        default_action = drop();
        size = 2048;
    }
    apply {
        if (hdr.ipv4.isValid()) { ipv4_fwd.apply(); }
    }
}
control B_IngressDeparser(packet_out pkt, inout b_ig_headers_t hdr, in b_ig_metadata_t meta,
        in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md) {
    apply { pkt.emit(hdr); }
}
parser B_EgressParser(packet_in pkt, out b_eg_headers_t hdr, out b_eg_metadata_t meta,
        out egress_intrinsic_metadata_t eg_intr_md) {
    state start { pkt.extract(eg_intr_md); transition accept; }
}
control B_Egress(inout b_eg_headers_t hdr, inout b_eg_metadata_t meta,
        in egress_intrinsic_metadata_t eg_intr_md,
        in egress_intrinsic_metadata_from_parser_t eg_prsr_md,
        inout egress_intrinsic_metadata_for_deparser_t eg_dprsr_md,
        inout egress_intrinsic_metadata_for_output_port_t eg_oport_md) {
    apply { }
}
control B_EgressDeparser(packet_out pkt, inout b_eg_headers_t hdr, in b_eg_metadata_t meta,
        in egress_intrinsic_metadata_for_deparser_t eg_dprsr_md) {
    apply { pkt.emit(hdr); }
}

/*==================== CONSOLIDATION : 4 pipelines (A,B,A,B) ====================*/
Pipeline(A_IngressParser(), A_Ingress(), A_IngressDeparser(),
         A_EgressParser(),  A_Egress(),  A_EgressDeparser()) pipe0;
Pipeline(B_IngressParser(), B_Ingress(), B_IngressDeparser(),
         B_EgressParser(),  B_Egress(),  B_EgressDeparser()) pipe1;
Pipeline(A_IngressParser(), A_Ingress(), A_IngressDeparser(),
         A_EgressParser(),  A_Egress(),  A_EgressDeparser()) pipe2;
Pipeline(B_IngressParser(), B_Ingress(), B_IngressDeparser(),
         B_EgressParser(),  B_Egress(),  B_EgressDeparser()) pipe3;

/* pipe0->pipe0(A), pipe1->pipe1(B), pipe2->pipe2(A), pipe3->pipe3(B) */
Switch(pipe0, pipe1, pipe2, pipe3) main;
