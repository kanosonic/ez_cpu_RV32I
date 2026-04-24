#!/usr/bin/env python3
import argparse
import random


GENERAL_REGS = [f"x{i}" for i in range(1, 31)]
LINK_REGS = [f"x{i}" for i in range(1, 28)]
BASE_REG = "x31"
JALR_TMP = "x29"

IMM_OPS = ["addi", "slti", "sltiu", "xori", "ori", "andi"]
SHIFT_IMM_OPS = ["slli", "srli", "srai"]
REG_OPS = ["add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and"]
BRANCH_OPS = ["beq", "bne", "blt", "bge", "bltu", "bgeu"]
LOAD_OPS = ["lb", "lbu", "lh", "lhu", "lw"]
STORE_OPS = ["sb", "sh", "sw"]


def random_reg(rng, exclude=None):
    if exclude is None:
        exclude = set()
    candidates = [reg for reg in GENERAL_REGS if reg not in exclude]
    return rng.choice(candidates)


def signed_imm(rng):
    return rng.randint(-2048, 2047)


def shift_imm(rng):
    return rng.randint(0, 31)


def small_signed_imm(rng):
    return rng.randint(-32, 31)


def aligned_offset(rng, op):
    if op in ("lw", "sw"):
        return rng.choice(range(0, 64, 4))
    if op in ("lh", "lhu", "sh"):
        return rng.choice(range(0, 64, 2))
    return rng.choice(range(0, 64))


def emit_init(lines, rng):
    lines.append(f"    lui {BASE_REG}, %hi(data_base)")
    lines.append(f"    addi {BASE_REG}, {BASE_REG}, %lo(data_base)")
    for reg in GENERAL_REGS:
        lines.append(f"    addi {reg}, x0, {signed_imm(rng)}")


def emit_imm_op(lines, rng):
    op = rng.choice(IMM_OPS)
    rd = random_reg(rng)
    rs = random_reg(rng)
    lines.append(f"    {op} {rd}, {rs}, {signed_imm(rng)}")


def emit_shift_imm_op(lines, rng):
    op = rng.choice(SHIFT_IMM_OPS)
    rd = random_reg(rng)
    rs = random_reg(rng)
    lines.append(f"    {op} {rd}, {rs}, {shift_imm(rng)}")


def emit_reg_op(lines, rng):
    op = rng.choice(REG_OPS)
    rd = random_reg(rng)
    rs1 = random_reg(rng)
    rs2 = random_reg(rng)
    lines.append(f"    {op} {rd}, {rs1}, {rs2}")


def emit_u_op(lines, rng):
    rd = random_reg(rng)
    imm20 = rng.randint(0, 0xFFFFF)
    op = rng.choice(["lui", "auipc"])
    lines.append(f"    {op} {rd}, 0x{imm20:x}")


def emit_mem_op(lines, rng):
    if rng.random() < 0.5:
        op = rng.choice(STORE_OPS)
        rs = random_reg(rng)
        off = aligned_offset(rng, op)
        lines.append(f"    {op} {rs}, {off}({BASE_REG})")
    else:
        op = rng.choice(LOAD_OPS)
        rd = random_reg(rng)
        off = aligned_offset(rng, op)
        lines.append(f"    {op} {rd}, {off}({BASE_REG})")


def emit_branch(lines, rng, label_id):
    op = rng.choice(BRANCH_OPS)
    rs1 = random_reg(rng)
    rs2 = random_reg(rng)
    rd = random_reg(rng)
    label = f"br_{label_id}"
    lines.append(f"    {op} {rs1}, {rs2}, {label}")
    lines.append(f"    addi {rd}, {rd}, {signed_imm(rng)}")
    lines.append(f"{label}:")


def emit_jal(lines, rng, label_id):
    rd = rng.choice(LINK_REGS)
    skip_reg = random_reg(rng)
    label = f"jal_{label_id}"
    lines.append(f"    jal {rd}, {label}")
    lines.append(f"    addi {skip_reg}, {skip_reg}, {signed_imm(rng)}")
    lines.append(f"{label}:")


def emit_jalr(lines, rng, label_id):
    rd = rng.choice(LINK_REGS)
    skip_reg = random_reg(rng)
    label = f"jalr_{label_id}"
    lines.append(f"    auipc {JALR_TMP}, 0")
    lines.append(f"    addi {JALR_TMP}, {JALR_TMP}, 16")
    lines.append(f"    jalr {rd}, {JALR_TMP}, 0")
    lines.append(f"    addi {skip_reg}, {skip_reg}, {signed_imm(rng)}")
    lines.append(f"{label}:")


def emit_loop(lines, rng, label_id):
    counter = random_reg(rng)
    state = random_reg(rng, {counter})
    temp = random_reg(rng, {counter, state})
    accum = random_reg(rng, {counter, state, temp})
    loop_label = f"real_loop_{label_id}"
    skip_label = f"real_loop_skip_{label_id}"
    iterations = rng.randint(3, 8)

    lines.append(f"    addi {counter}, x0, {iterations}")
    lines.append(f"    addi {state}, x0, {rng.randint(0, 1)}")
    lines.append(f"{loop_label}:")
    lines.append(f"    andi {temp}, {state}, 1")
    lines.append(f"    beq {temp}, x0, {skip_label}")

    if rng.random() < 0.5:
        lines.append(f"    addi {accum}, {accum}, {small_signed_imm(rng)}")
    else:
        lines.append(f"    xori {accum}, {accum}, {rng.randint(0, 31)}")

    lines.append(f"{skip_label}:")
    if rng.random() < 0.5:
        lines.append(f"    sw {accum}, {aligned_offset(rng, 'sw')}({BASE_REG})")
    else:
        lines.append(f"    lw {accum}, {aligned_offset(rng, 'lw')}({BASE_REG})")
    lines.append(f"    xori {state}, {state}, 1")
    lines.append(f"    addi {counter}, {counter}, -1")
    lines.append(f"    bne {counter}, x0, {loop_label}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, required=True)
    parser.add_argument("--steps", type=int, default=32)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    rng = random.Random(args.seed)
    lines = [
        ".globl _start",
        f"# seed={args.seed}",
        "_start:",
    ]

    emit_init(lines, rng)

    label_id = 0
    for _ in range(args.steps):
        kind = rng.choices(
            ["imm", "shift", "reg", "uop", "mem", "branch", "jal", "jalr", "loop"],
            weights=[18, 9, 20, 8, 14, 12, 6, 5, 8],
            k=1,
        )[0]

        if kind == "imm":
            emit_imm_op(lines, rng)
        elif kind == "shift":
            emit_shift_imm_op(lines, rng)
        elif kind == "reg":
            emit_reg_op(lines, rng)
        elif kind == "uop":
            emit_u_op(lines, rng)
        elif kind == "mem":
            emit_mem_op(lines, rng)
        elif kind == "branch":
            emit_branch(lines, rng, label_id)
            label_id += 1
        elif kind == "jal":
            emit_jal(lines, rng, label_id)
            label_id += 1
        elif kind == "jalr":
            emit_jalr(lines, rng, label_id)
            label_id += 1
        else:
            emit_loop(lines, rng, label_id)
            label_id += 1

    lines.extend(
        [
            "loop:",
            "    addi x0, x0, 0",
            "    j loop",
            "    .balign 64",
            "data_base:",
            "    .space 64",
            "",
        ]
    )

    with open(args.output, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


if __name__ == "__main__":
    main()
