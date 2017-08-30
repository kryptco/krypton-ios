//
//  SSHHostVerificationTests.swift
//  Kryptonite
//
//  Created by Kevin King on 3/29/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import XCTest
@testable import Kryptonite

class HostAuthTestCase {
    let pk: String
    let sig: String
    let data: String

    init(pk: String, sig: String, data: String) {
        self.pk = pk
        self.sig = sig
        self.data = data
    }
}

class SSHHostVerificationTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    let rsaSigEqualSizeModulus = HostAuthTestCase(
        pk: "AAAAB3NzaC1yc2EAAAADAQABAAABAQCy+nQ5jr9m4Mil8Llh6nqdN8uX25eljQfaoFdl8K1ufNt26BulxMn41prse+k5cDueL6w06xglVtx1FU4S8uhkbB2WZo05shnUvoNXU6hfQR0nT0Esfk8PqjOl69JVnV8NmVGtSmnMVgJNlvXdQrvvWcDYyI8RLR5bvVFrvMhjSOk8Vb81eJ5TqgJ/Ae+UsG1+uSjySORIuuv7vFsQNB93RE8d68LjQ6QDZB8j02UFNlwsGb+SKEufAlkOgGHTDS3P6lxZLc0AW5691vL58D253CpzNBcnu5llbrdfr/XKoOCQusMOclBN69LrbPWvTx6Tvs3CBwH7XY6WuATId+Wr",
        sig: "AAAAB3NzaC1yc2EAAAEADQc5AG5LwQyee6txeY+XvrQ8/+ihJ84vz4nK4Jtpv3r6efPvq20UgAbTzhx/03RGdo+nZtRumCWDFHrW45unEdcSHuzlrm9v9UVwpKseQO89SnDpA2Tt6UBlJZuVixkldlhFlmrun+GeAxYHxVLeSEL7oaZ/TicQnQFMCvcfD82YMUXxk81SIssEtUVyZOq9Qi2h37xwNz+sSYO37Hkof6nYuJ529DgxcRiJEzIRN03oNoglRi8IZz8LHBLxu3dr/jikxXkZ1/YFt/FMGjhDlp3Yxqj2CPxJ+uyfaCJgbLcgv8tfhSiE8DxOK/WMyP6bLxnC04AOcsrY7Cn9BdvMpw==",
        data: "AAAAIKce60VmSoQEa5zV24zb/yEZnVxNnZ4rxPgFYVg29uhUMgAAAANnaXQAAAAOc3NoLWNvbm5lY3Rpb24AAAAJcHVibGlja2V5AQAAAAdzc2gtcnNh"
    )


    let rsaSigSmallerThanModulus = HostAuthTestCase(
        pk: "AAAAB3NzaC1yc2EAAAADAQABAAABAQCy+nQ5jr9m4Mil8Llh6nqdN8uX25eljQfaoFdl8K1ufNt26BulxMn41prse+k5cDueL6w06xglVtx1FU4S8uhkbB2WZo05shnUvoNXU6hfQR0nT0Esfk8PqjOl69JVnV8NmVGtSmnMVgJNlvXdQrvvWcDYyI8RLR5bvVFrvMhjSOk8Vb81eJ5TqgJ/Ae+UsG1+uSjySORIuuv7vFsQNB93RE8d68LjQ6QDZB8j02UFNlwsGb+SKEufAlkOgGHTDS3P6lxZLc0AW5691vL58D253CpzNBcnu5llbrdfr/XKoOCQusMOclBN69LrbPWvTx6Tvs3CBwH7XY6WuATId+Wr",
        sig: "AAAAB3NzaC1yc2EAAAEAAGFtFeQVT+Js31n+S3YuAs3Hx08CKv8XAREoqm+uq40j8qPQG/fRCqB3lT+PkwDdLibqIbLCHKAThJq9ft+hZxa/xv3LegxjJvNhXHR8pk2BxnZXQvs6RmJjFHUJHY8/bylA+zSYssOYdeq6PJogTudJ9NenlksmFPmQ4VkCdp3JPo2Y+JEuT7CcSNYL4zrQMXXLTfZV0/SZ0E3Z+ZBJttQI8c68WNd++rPt7tFkvmbb/k7TtSt2pwIZqHX15WKkm/41An/WqXcUwk2VMdUf36SG5X2qPzCC9yPAqphhSKitFOXQaP3nEWGocbSb6vpBACb+MRbjdFGkdCJDfAzQvQ==",
        data: "AAAAIE5yHvfefACpf4gX/T7jFE0kbT5VFAQA5dOaa817rvN5MgAAAANnaXQAAAAOc3NoLWNvbm5lY3Rpb24AAAAJcHVibGlja2V5AQAAAAdzc2gtcnNh"
    )

    let ecdsaCase = HostAuthTestCase(
            pk: "AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBFsz+iDSG34GRKn6M6qhbn7BTQrRcz5l+ZE9sbcBvvUJlGahkvGscr/y2ucl85XQFYkGdV04cfNr1jMoDicQHRM=",
            sig: "AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAABJAAAAIFvpL0Zg1oNIx5fD2y9Gf2zwXPrWap4XuMz+WutTVQK9AAAAIQC623uwOYif3Hg6gOapgRslsVAY9W0GkqFxbfq7sHFFtA==",
            data: "AAAAILqtiL9S+34rm3Jetl4QpbCUFmeLNM31u6go/e702npgMgAAAANnaXQAAAAOc3NoLWNvbm5lY3Rpb24AAAAJcHVibGlja2V5AQAAAAdzc2gtcnNh"
    )

    let ed25519Case = HostAuthTestCase(
        pk: "AAAAC3NzaC1lZDI1NTE5AAAAIK4WjSfJ9SmETrpAjw7+0znqMsHTXzY/b6AXCRoQzzuI",
        sig: "AAAAC3NzaC1lZDI1NTE5AAAAQFBf15H9MeZ32f3cgdfzicIM70teC23wMDVFN/+gRW73YyjiZpFamjJ56jjVv+fZVsoaijs42/RlOV/wMNI+3w8=",
        data: "AAAAIPETRn52JvtGonHlvKDDzk02/9p8GKioagvG+nEU3+h9MgAAAANnaXQAAAAOc3NoLWNvbm5lY3Rpb24AAAAJcHVibGlja2V5AQAAAAdzc2gtcnNh"
    )

    func testHostAuth() {
    
        print("Doing rsaSigSmallerThanModulus")
        runCase(testCase: rsaSigSmallerThanModulus)
        
        print("Doing rsaSigEqualSizeModulus")
        runCase(testCase: rsaSigEqualSizeModulus)
        
        print("Doing ecdsaCase")
        runCase(testCase: ecdsaCase)
        
        print("Doing ed25519Case")
        runCase(testCase: ed25519Case)
    }

    func runCase(testCase: HostAuthTestCase) {
        do {
            let signRequest = try SignRequest(
                data: try testCase.data.fromBase64(),
                fingerprint: "",
                hostAuth: HostAuth(
                    hostKey: testCase.pk,
                    signature: testCase.sig,
                    hostNames: []
                    )
            )
            XCTAssert(signRequest.user == "git")
            XCTAssert(signRequest.verifiedHostAuth != nil)
        } catch let e {
            XCTFail("\(e)")
        }
    }

    func testInvalidSessionData() {
        do {
            if !KeyManager.hasKey() {
                try! KeyManager.generateKeyPair(type: .Ed25519)
            }
            let fp = try KeyManager.sharedInstance().keyPair.publicKey.fingerprint().toBase64()
            let invalidData = try "jHspdr8xb+91IetQiVJUvA==".fromBase64()
            let _ = try SignRequest(data: invalidData, fingerprint: fp, hostAuth: nil)
            XCTFail("expected exception")
        } catch let e {
            guard let _ = e as? SSHMessageParsingError else {
                XCTFail("\(e)")
                return
            }
        }
    }
}
